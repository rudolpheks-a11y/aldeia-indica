package handler

import (
	"encoding/json"
	"fmt"
	"net/http"
	"regexp"

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

var validObjectTypes = map[string]bool{
	"avatar":     true,
	"work_photo": true,
	"chat_image": true,
	"document":   true,
}

// unsafeKeyChars strips anything that isn't alphanumeric/dash/dot/underscore —
// o filename do cliente vira parte literal da chave do S3; sem isso, um
// nome de arquivo com barra, caractere de controle ou tamanho absurdo entra
// direto na chave (S3 não resolve "..", mas nada te protege desses outros
// casos hoje).
var unsafeKeyChars = regexp.MustCompile(`[^a-zA-Z0-9._-]`)

func sanitizeFilename(name string) string {
	clean := unsafeKeyChars.ReplaceAllString(name, "_")
	if len(clean) > 100 {
		clean = clean[len(clean)-100:]
	}
	if clean == "" {
		return "file"
	}
	return clean
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
	if !validObjectTypes[in.ObjectType] {
		jsonError(w, "invalid object_type", http.StatusBadRequest)
		return
	}

	isPrivate := in.ObjectType == "document"
	key := fmt.Sprintf("%s/%s/%s/%s",
		claims.CommunityID, in.ObjectType, claims.UserID,
		uuid.New().String()+"-"+sanitizeFilename(in.Filename),
	)

	result, err := h.s3.PresignPut(r.Context(), key, isPrivate)
	if err != nil {
		jsonError(w, "failed to generate upload URL", http.StatusInternalServerError)
		return
	}
	jsonOK(w, result)
}
