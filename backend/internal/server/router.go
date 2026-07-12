package server

import (
	"log/slog"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	chimiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/go-chi/httprate"
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
	notifH *handler.NotificationHandler,
	questionH *handler.QuestionHandler,
	userH *handler.UserHandler,
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

	// Rate limits for pre-auth endpoints that trigger account creation or an
	// outbound email — IP-based since there's no authenticated identity yet.
	authRateLimit := httprate.LimitByIP(5, time.Minute)

	r.Route("/api/v1", func(r chi.Router) {
		// Public
		r.With(authRateLimit).Post("/auth/register/morador", authH.RegisterMorador)
		r.With(authRateLimit).Post("/auth/register/prestador", authH.RegisterPrestador)
		r.With(authRateLimit).Post("/auth/login", authH.Login)
		// Reativação de conta autoexcluída — mesma proteção do login, já que
		// também recebe e-mail + senha.
		r.With(authRateLimit).Post("/auth/reactivate", authH.Reactivate)
		r.Post("/auth/refresh", authH.Refresh)
		r.With(authRateLimit).Post("/auth/forgot-password", authH.ForgotPassword)
		r.With(authRateLimit).Post("/auth/reset-password", authH.ResetPassword)

		// Invite validation (public)
		r.Get("/invites/{token}", approvalH.ValidateInvite)

		// Authenticated routes
		r.Group(func(r chi.Router) {
			r.Use(middleware.Authenticate(j))

			r.Post("/auth/logout", authH.Logout)

			// Exclusão da própria conta (morador e prestador)
			r.Delete("/users/me", userH.DeleteMe)

			r.Get("/categories", categoryH.List)

			// Providers
			// Buscar prestadores é exclusivo do morador (decisão de produto):
			// prestador não procura prestador. Perfil por id e /providers/me
			// seguem abertos — o prestador precisa deles pro tile "Ver meu
			// perfil público" e pras telas de edição.
			r.With(middleware.RequireRole("morador")).Get("/providers", providerH.Search)
			r.With(middleware.RequireRole("morador")).Get("/providers/featured", providerH.Featured)
			r.Get("/providers/favorites", providerH.ListFavorites)
			r.Get("/providers/me", providerH.GetMe)
			r.Get("/providers/me/ratings/summary", providerH.MyRatingSummary)
			r.Put("/providers/me/availability", providerH.UpdateMyAvailability)
			r.Get("/providers/{id}", providerH.Get)
			r.Put("/providers/me", providerH.UpdateMe)
			r.Post("/providers/{id}/favorite", providerH.Favorite)
			r.Delete("/providers/{id}/favorite", providerH.Unfavorite)
			r.Get("/providers/{id}/questions", questionH.List)
			r.Post("/providers/{id}/questions", questionH.Ask)
			r.Post("/providers/{id}/questions/{qid}/answers", questionH.Answer)
			r.Get("/dashboard/summary", providerH.Dashboard)

			// Mural de avisos (apenas moradores lêem e postam)
			// O mural é interação exclusiva entre moradores (decisão de
			// produto) — prestador não lê nem publica. A moderação do admin
			// usa /admin/bulletin/*, que não passa por aqui.
			r.With(middleware.RequireRole("morador")).Get("/bulletin", bulletinH.ListApproved)
			r.With(middleware.RequireRole("morador")).Post("/bulletin", bulletinH.Create)

			// Ratings
			r.Post("/ratings", ratingH.Create)
			r.Get("/ratings/provider/{id}", ratingH.ListByProvider)

			// Recommendations — no single-column recommendation id exists in
			// the schema (natural key is community+provider+recommender), so
			// Delete takes provider_id in the body, symmetric with Create.
			r.Post("/recommendations", recH.Create)
			r.Delete("/recommendations", recH.Delete)
			r.Get("/recommendations/provider/{id}", recH.ListByProvider)

			// Convites — morador ativo gera, candidato consome 2 no cadastro
			// (ver AuthHandler.RegisterMorador), não precisa de rota de "usar"
			// pós-login.
			r.Post("/invites", approvalH.CreateInvite)

			// Service requests
			r.Get("/requests", requestH.List)
			r.Post("/requests", requestH.Create)
			r.Get("/requests/{id}", requestH.Get)
			r.Put("/requests/{id}", requestH.UpdateStatus)
			r.Post("/requests/{id}/responses", requestH.Respond)
			r.Get("/requests/{id}/responses", requestH.ListResponses)

			// Notificações
			r.Get("/notifications", notifH.List)
			r.Get("/notifications/unread-count", notifH.UnreadCount)
			r.Post("/notifications/read-all", notifH.MarkAllRead)

			// Chat (REST)
			r.Post("/chat/conversations", chatH.GetOrCreate)
			r.Get("/chat/conversations", chatH.ListConversations)
			r.Get("/chat/conversations/{id}/messages", chatH.ListMessages)
			r.Post("/chat/conversations/{id}/read", chatH.MarkRead)

			// Uploads — each call mints a valid S3 write URL, cap abuse/cost
			r.With(httprate.LimitByIP(30, time.Minute)).Post("/uploads/presign", uploadH.Presign)

			// Admin
			r.Group(func(r chi.Router) {
				r.Use(middleware.RequireRole("admin"))
				r.Get("/admin/stats", adminH.Stats)
				r.Get("/admin/users", adminH.ListUsers)
				r.Put("/admin/users/{id}/status", adminH.UpdateUserStatus)
				r.Delete("/admin/users/{id}", userH.DeleteUser)
				r.Get("/admin/provider-services", adminH.ListProviderServices)
				r.Get("/admin/ratings", adminH.ListRatings)
				r.Get("/admin/recommendations", adminH.ListRecommendations)
				r.Post("/admin/communities", adminH.CreateCommunity)
				r.Get("/admin/bulletin/pending", bulletinH.ListPending)
				r.Post("/admin/bulletin/{id}/review", bulletinH.Review)
			})
		})
	})

	return r
}
