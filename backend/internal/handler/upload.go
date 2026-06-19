package handler

import (
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/google/uuid"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/server/middleware"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/storage"
)

type UploadHandler struct {
	s3 *storage.S3Client
}

func NewUploadHandler(s3 *storage.S3Client) *UploadHandler {
	return &UploadHandler{s3: s3}
}

func (h *UploadHandler) Presign(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())

	var in struct {
		ObjectType string `json:"object_type"` // avatar, work_photo, chat_image, document
		Filename   string `json:"filename"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		jsonError(w, "invalid body", http.StatusBadRequest)
		return
	}

	isPrivate := in.ObjectType == "document"
	key := fmt.Sprintf("%s/%s/%s/%s",
		claims.CommunityID, in.ObjectType, claims.UserID, uuid.New().String()+"-"+in.Filename,
	)

	result, err := h.s3.PresignPut(r.Context(), key, isPrivate)
	if err != nil {
		jsonError(w, "failed to generate upload URL", http.StatusInternalServerError)
		return
	}
	jsonOK(w, result)
}
