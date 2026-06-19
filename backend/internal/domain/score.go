package domain

import "math"

type ProviderStats struct {
	AvgRating            float64
	YearsInNeighborhood  int
	TotalClients         int
	TotalHires           int
	RecommendationCount  int
}

func CalculateScore(p ProviderStats) float64 {
	rating := (p.AvgRating / 5.0) * 35
	years := math.Min(float64(p.YearsInNeighborhood)/10.0, 1.0) * 15
	clients := math.Min(float64(p.TotalClients)/50.0, 1.0) * 20
	hires := math.Min(float64(p.TotalHires)/100.0, 1.0) * 15
	recs := math.Min(float64(p.RecommendationCount)/20.0, 1.0) * 15
	return math.Round((rating+years+clients+hires+recs)*100) / 100
}
