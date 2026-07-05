package domain_test

import (
	"testing"

	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/domain"
)

func TestCalculateScore(t *testing.T) {
	tests := []struct {
		name     string
		stats    domain.ProviderStats
		wantMin  float64
		wantMax  float64
	}{
		{
			name: "perfect provider",
			stats: domain.ProviderStats{
				AvgRating:           5.0,
				YearsInNeighborhood: 10,
				TotalClients:        50,
				RecommendationCount: 20,
			},
			wantMin: 99,
			wantMax: 100,
		},
		{
			name: "new provider no ratings",
			stats: domain.ProviderStats{
				AvgRating:           0,
				YearsInNeighborhood: 0,
				TotalClients:        0,
				RecommendationCount: 0,
			},
			wantMin: 0,
			wantMax: 0,
		},
		{
			name: "good provider partial metrics",
			stats: domain.ProviderStats{
				AvgRating:           4.5,
				YearsInNeighborhood: 5,
				TotalClients:        25,
				RecommendationCount: 10,
			},
			wantMin: 50,
			wantMax: 80,
		},
		{
			name: "caps at 100 with overflow values",
			stats: domain.ProviderStats{
				AvgRating:           5.0,
				YearsInNeighborhood: 20,
				TotalClients:        200,
				RecommendationCount: 100,
			},
			wantMin: 99,
			wantMax: 100,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := domain.CalculateScore(tt.stats)
			if got < tt.wantMin || got > tt.wantMax {
				t.Errorf("CalculateScore() = %v, want between %v and %v", got, tt.wantMin, tt.wantMax)
			}
		})
	}
}
