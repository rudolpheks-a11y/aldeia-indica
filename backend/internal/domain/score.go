package domain

import "math"

type ProviderStats struct {
	AvgRating           float64
	YearsInNeighborhood int
	TotalClients        int
	RecommendationCount int
}

// Pesos somam 100. "Contratação confirmada" saiu da fórmula (e do produto
// como um todo) — o app existe pra facilitar achar prestadores e formar uma
// rede de confiança via avaliação/indicação, não pra rastrear se alguém
// fechou negócio. O peso que era de TotalHires (15) foi pra TotalClients,
// que já é o proxy real de "gente que efetivamente usou o serviço" (conta
// avaliadores distintos, calculado em rating.go).
func CalculateScore(p ProviderStats) float64 {
	rating := (p.AvgRating / 5.0) * 40
	years := math.Min(float64(p.YearsInNeighborhood)/10.0, 1.0) * 15
	clients := math.Min(float64(p.TotalClients)/50.0, 1.0) * 30
	recs := math.Min(float64(p.RecommendationCount)/20.0, 1.0) * 15
	return math.Round((rating+years+clients+recs)*100) / 100
}
