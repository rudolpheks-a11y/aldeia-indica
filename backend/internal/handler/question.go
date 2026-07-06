package handler

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/server/middleware"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/service"
)

type QuestionHandler struct {
	db       *pgxpool.Pool
	notifSvc *service.NotificationService
}

func NewQuestionHandler(db *pgxpool.Pool, notifSvc *service.NotificationService) *QuestionHandler {
	return &QuestionHandler{db: db, notifSvc: notifSvc}
}

func (h *QuestionHandler) Ask(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	providerID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}
	if providerID == claims.UserID {
		jsonError(w, "cannot ask a question on your own profile", http.StatusForbidden)
		return
	}

	var in struct {
		Question string `json:"question"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil || in.Question == "" {
		jsonError(w, "invalid body", http.StatusBadRequest)
		return
	}

	var id uuid.UUID
	err = h.db.QueryRow(r.Context(),
		`INSERT INTO provider_questions (community_id, provider_id, asker_id, question)
		 SELECT $1, pp.user_id, $2, $3 FROM provider_profiles pp
		 WHERE pp.user_id=$4 AND pp.community_id=$1
		 RETURNING id`,
		claims.CommunityID, claims.UserID, in.Question, providerID,
	).Scan(&id)
	if err != nil {
		jsonError(w, "provider not found", http.StatusNotFound)
		return
	}

	// Best-effort: a pergunta já foi salva, uma falha ao notificar não pode
	// virar erro pra quem perguntou.
	_ = h.notifSvc.Create(r.Context(), claims.CommunityID, providerID,
		"question_received", "Nova pergunta no seu perfil",
		"Um morador perguntou: \""+in.Question+"\"", &id)

	w.WriteHeader(http.StatusCreated)
	jsonOK(w, map[string]string{"id": id.String()})
}

func (h *QuestionHandler) List(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	providerID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}

	rows, err := h.db.Query(r.Context(),
		`SELECT pq.id, u.full_name, pq.question, pq.created_at
		 FROM provider_questions pq JOIN users u ON u.id = pq.asker_id
		 WHERE pq.provider_id=$1 AND pq.community_id=$2
		 ORDER BY pq.created_at DESC`,
		providerID, claims.CommunityID,
	)
	if err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}

	type question struct {
		ID        uuid.UUID
		Asker     string
		Question  string
		CreatedAt time.Time
	}
	var questions []question
	var ids []uuid.UUID
	for rows.Next() {
		var q question
		if err := rows.Scan(&q.ID, &q.Asker, &q.Question, &q.CreatedAt); err != nil {
			rows.Close()
			jsonError(w, "internal error", http.StatusInternalServerError)
			return
		}
		questions = append(questions, q)
		ids = append(ids, q.ID)
	}
	rowsErr := rows.Err()
	rows.Close()
	if rowsErr != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}

	answersByQuestion := map[uuid.UUID][]map[string]any{}
	if len(ids) > 0 {
		aRows, err := h.db.Query(r.Context(),
			`SELECT pqa.question_id, u.full_name, pqa.answer, pqa.created_at
			 FROM provider_question_answers pqa JOIN users u ON u.id = pqa.responder_id
			 WHERE pqa.question_id = ANY($1)
			 ORDER BY pqa.created_at ASC`,
			ids,
		)
		if err != nil {
			jsonError(w, "internal error", http.StatusInternalServerError)
			return
		}
		for aRows.Next() {
			var qid uuid.UUID
			var responder, answer string
			var createdAt time.Time
			if err := aRows.Scan(&qid, &responder, &answer, &createdAt); err != nil {
				aRows.Close()
				jsonError(w, "internal error", http.StatusInternalServerError)
				return
			}
			answersByQuestion[qid] = append(answersByQuestion[qid], map[string]any{
				"responder": responder, "answer": answer, "created_at": createdAt,
			})
		}
		aRowsErr := aRows.Err()
		aRows.Close()
		if aRowsErr != nil {
			jsonError(w, "internal error", http.StatusInternalServerError)
			return
		}
	}

	result := make([]map[string]any, 0, len(questions))
	for _, q := range questions {
		answers := answersByQuestion[q.ID]
		if answers == nil {
			answers = []map[string]any{}
		}
		result = append(result, map[string]any{
			"id": q.ID, "asker": q.Asker, "question": q.Question,
			"created_at": q.CreatedAt, "answers": answers,
		})
	}
	jsonOK(w, result)
}

func (h *QuestionHandler) Answer(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	questionID, err := uuid.Parse(chi.URLParam(r, "qid"))
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}

	var in struct {
		Answer string `json:"answer"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil || in.Answer == "" {
		jsonError(w, "invalid body", http.StatusBadRequest)
		return
	}

	tag, err := h.db.Exec(r.Context(),
		`INSERT INTO provider_question_answers (question_id, community_id, responder_id, answer)
		 SELECT id, community_id, $2, $3 FROM provider_questions WHERE id=$1 AND community_id=$4`,
		questionID, claims.UserID, in.Answer, claims.CommunityID,
	)
	if err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	if tag.RowsAffected() == 0 {
		jsonError(w, "question not found", http.StatusNotFound)
		return
	}
	w.WriteHeader(http.StatusCreated)
}
