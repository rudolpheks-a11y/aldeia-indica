package server

import (
	"log/slog"
	"net/http"

	"github.com/go-chi/chi/v5"
	chimiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/auth"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/handler"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/server/middleware"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/ws"
)

func NewRouter(
	log *slog.Logger,
	j *auth.JWT,
	authH *handler.AuthHandler,
	providerH *handler.ProviderHandler,
	ratingH *handler.RatingHandler,
	recH *handler.RecommendationHandler,
	approvalH *handler.ApprovalHandler,
	requestH *handler.RequestHandler,
	uploadH *handler.UploadHandler,
	adminH *handler.AdminHandler,
	categoryH *handler.CategoryHandler,
	chatH *handler.ChatHandler,
	bulletinH *handler.BulletinHandler,
	wsH *ws.Handler,
) http.Handler {
	r := chi.NewRouter()

	r.Use(chimiddleware.Recoverer)
	r.Use(middleware.Logger(log))
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type"},
		AllowCredentials: false,
	}))

	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})

	// Public communities list (used on login/register screen)
	r.Get("/api/v1/communities", adminH.ListCommunities)

	// WebSocket endpoint — auth via ?token= query param
	r.Get("/ws/chat", wsH.ServeHTTP)

	r.Route("/api/v1", func(r chi.Router) {
		// Public
		r.Post("/auth/register/morador", authH.RegisterMorador)
		r.Post("/auth/register/prestador", authH.RegisterPrestador)
		r.Post("/auth/login", authH.Login)
		r.Post("/auth/refresh", authH.Refresh)
		r.Post("/auth/forgot-password", authH.ForgotPassword)
		r.Post("/auth/reset-password", authH.ResetPassword)
		r.Get("/categories", categoryH.List)

		// Invite validation (public)
		r.Get("/invites/{token}", approvalH.ValidateInvite)

		// Authenticated routes
		r.Group(func(r chi.Router) {
			r.Use(middleware.Authenticate(j))

			r.Post("/auth/logout", authH.Logout)

			// Providers
			r.Get("/providers", providerH.Search)
			r.Get("/providers/featured", providerH.Featured)
			r.Get("/providers/me", providerH.GetMe)
			r.Get("/providers/me/ratings/summary", providerH.MyRatingSummary)
			r.Put("/providers/me/availability", providerH.UpdateMyAvailability)
			r.Get("/providers/{id}", providerH.Get)
			r.Put("/providers/me", providerH.UpdateMe)
			r.Post("/providers/{id}/photos", providerH.AddPhoto)
			r.Delete("/providers/{id}/photos/{photoID}", providerH.DeletePhoto)
			r.Post("/providers/{id}/hire", providerH.HireCompleted)
			r.Get("/dashboard/summary", providerH.Dashboard)

			// Mural de avisos (apenas moradores lêem e postam)
			r.Get("/bulletin", bulletinH.ListApproved)
			r.Post("/bulletin", bulletinH.Create)

			// Ratings
			r.Post("/ratings", ratingH.Create)
			r.Get("/ratings/provider/{id}", ratingH.ListByProvider)

			// Recommendations
			r.Post("/recommendations", recH.Create)
			r.Delete("/recommendations/{id}", recH.Delete)
			r.Get("/recommendations/provider/{id}", recH.ListByProvider)

			// Approvals
			r.Get("/approvals/pending", approvalH.ListPending)
			r.Post("/approvals/{id}/vote", approvalH.Vote)
			r.Post("/invites", approvalH.CreateInvite)
			r.Post("/invites/{token}/use", approvalH.UseInvite)

			// Service requests
			r.Get("/requests", requestH.List)
			r.Post("/requests", requestH.Create)
			r.Get("/requests/{id}", requestH.Get)
			r.Put("/requests/{id}", requestH.UpdateStatus)
			r.Post("/requests/{id}/responses", requestH.Respond)
			r.Get("/requests/{id}/responses", requestH.ListResponses)

			// Chat (REST)
			r.Post("/chat/conversations", chatH.GetOrCreate)
			r.Get("/chat/conversations", chatH.ListConversations)
			r.Get("/chat/conversations/{id}/messages", chatH.ListMessages)
			r.Post("/chat/conversations/{id}/read", chatH.MarkRead)

			// Uploads
			r.Post("/uploads/presign", uploadH.Presign)

			// Admin
			r.Group(func(r chi.Router) {
				r.Use(middleware.RequireRole("admin"))
				r.Get("/admin/users", adminH.ListUsers)
				r.Put("/admin/users/{id}/status", adminH.UpdateUserStatus)
				r.Get("/admin/documents", adminH.ListDocumentQueue)
				r.Post("/admin/documents/{providerID}/review", adminH.ReviewDocument)
				r.Post("/admin/communities", adminH.CreateCommunity)
				r.Post("/approvals/{id}/resolve", approvalH.AdminResolve)
				r.Get("/admin/bulletin/pending", bulletinH.ListPending)
				r.Post("/admin/bulletin/{id}/review", bulletinH.Review)
			})
		})
	})

	return r
}
