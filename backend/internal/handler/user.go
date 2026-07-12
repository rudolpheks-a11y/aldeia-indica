package handler

import (
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/server/middleware"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/service"
)

type UserHandler struct {
	userSvc *service.UserService
}

func NewUserHandler(userSvc *service.UserService) *UserHandler {
	return &UserHandler{userSvc: userSvc}
}

// DeleteMe — o próprio usuário exclui a conta. É anonimização, não DELETE
// físico (ver UserService.DeleteAccount). Vale para morador e prestador; o
// admin não se autoexclui por aqui, senão a comunidade fica sem moderador.
func (h *UserHandler) DeleteMe(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())

	if claims.Role == "admin" {
		jsonError(w, "administradores não podem desativar a própria conta", http.StatusForbidden)
		return
	}

	// deletedBy = o próprio usuário: é autoexclusão, então ele pode
	// reativar depois fazendo login com a senha antiga.
	if err := h.userSvc.DeleteAccount(r.Context(), claims.UserID, claims.UserID); err != nil {
		if errors.Is(err, service.ErrUserNotFound) {
			jsonError(w, "conta não encontrada", http.StatusNotFound)
			return
		}
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// DeleteUser — o admin exclui a conta de um morador ou prestador.
func (h *UserHandler) DeleteUser(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())

	targetID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		jsonError(w, "id inválido", http.StatusBadRequest)
		return
	}

	// Um admin se excluindo deixaria a comunidade sem quem aprove moradores e
	// modere o mural — e ele não teria como se reativar.
	if targetID == claims.UserID {
		jsonError(w, "você não pode desativar a própria conta de admin", http.StatusForbidden)
		return
	}

	// O admin só alcança a própria comunidade (multi-tenancy) — sem isso ele
	// excluiria usuário de outro bairro passando o UUID direto.
	// deletedBy = o admin: o dono NÃO reativa sozinho depois.
	if err := h.userSvc.DeleteAccountAsAdmin(r.Context(), targetID, claims.CommunityID, claims.UserID); err != nil {
		if errors.Is(err, service.ErrUserNotFound) {
			jsonError(w, "usuário não encontrado", http.StatusNotFound)
			return
		}
		if errors.Is(err, service.ErrCannotDeleteSelf) {
			jsonError(w, "não é possível desativar outro administrador", http.StatusForbidden)
			return
		}
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
