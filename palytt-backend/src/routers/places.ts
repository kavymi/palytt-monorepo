import { z } from 'zod';
import { router, publicProcedure } from '../trpc.js';

// Input validation schemas
const placeSearchRequestSchema = z.object({
  query: z.string().min(1, 'Query is required'),
  latitude: z.number().optional(),
  longitude: z.number().optional(),
  radius: z.number().int().min(100).max(50000).default(5000), // 100m to 50km
  limit: z.number().int().min(1).max(50).default(20)
});

// Response type for place search results
const placeSearchResultSchema = z.object({
  id: z.string(),
  name: z.string(),
  address: z.string(),
  latitude: z.number(),
  longitude: z.number(),
  rating: z.number().optional(),
  priceLevel: z.number().int().min(0).max(4).optional(),
  types: z.array(z.string()),
  placeId: z.string().optional(),
  photoUrl: z.string().optional()
});

export type PlaceSearchResult = z.infer<typeof placeSearchResultSchema>;

/**
 * Places router for handling location-based place searches
 */
export const placesRouter = router({
  /**
   * Search for places using Google Places API or similar service
   */
  search: publicProcedure
    .input(placeSearchRequestSchema)
    .output(z.array(placeSearchResultSchema))
    .query(async ({ input }) => {
      const { query, latitude, longitude, radius, limit } = input;
      
      try {
        console.log(`🔍 Places Search: "${query}" ${latitude && longitude ? `at (${latitude}, ${longitude})` : 'globally'} within ${radius}m radius, limit: ${limit}`);
        
        // For now, return mock data that matches the expected structure
        // TODO: Integrate with Google Places API or similar service
        const mockPlaces: PlaceSearchResult[] = [
          {
            id: "place_1",
            name: "The Coffee Bean & Tea Leaf",
            address: "123 Main St, San Francisco, CA 94102",
            latitude: latitude ? latitude + 0.001 : 37.7749,
            longitude: longitude ? longitude + 0.001 : -122.4194,
            rating: 4.2,
            priceLevel: 2,
            types: ["cafe", "restaurant", "food"],
            placeId: "ChIJd8BlQ2BZwokRAFUEcm_qrcA",
            photoUrl: "https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=400"
          },
          {
            id: "place_2", 
            name: "Mario's Italian Restaurant",
            address: "456 Union Square, San Francisco, CA 94108",
            latitude: latitude ? latitude + 0.002 : 37.7849,
            longitude: longitude ? longitude + 0.002 : -122.4094,
            rating: 4.5,
            priceLevel: 3,
            types: ["restaurant", "food", "italian"],
            placeId: "ChIJd8BlQ2BZwokRAFUEcm_qrcB",
            photoUrl: "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=400"
          },
          {
            id: "place_3",
            name: "Golden Gate Brew Co",
            address: "789 Market St, San Francisco, CA 94103", 
            latitude: latitude ? latitude - 0.001 : 37.7649,
            longitude: longitude ? longitude - 0.001 : -122.4294,
            rating: 4.0,
            priceLevel: 2,
            types: ["bar", "restaurant", "brewery"],
            placeId: "ChIJd8BlQ2BZwokRAFUEcm_qrcC",
            photoUrl: "https://images.unsplash.com/photo-1578328819058-b69f3a3b0f6b?w=400"
          },
          {
            id: "place_4",
            name: "Sushi Zen",
            address: "321 Geary St, San Francisco, CA 94102",
            latitude: latitude ? latitude + 0.003 : 37.7949,
            longitude: longitude ? longitude - 0.002 : -122.4394,
            rating: 4.7,
            priceLevel: 4,
            types: ["restaurant", "food", "japanese", "sushi"],
            placeId: "ChIJd8BlQ2BZwokRAFUEcm_qrcD",
            photoUrl: "https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=400"
          },
          {
            id: "place_5",
            name: "Organic Smoothie Bar",
            address: "654 Castro St, San Francisco, CA 94114",
            latitude: latitude ? latitude - 0.002 : 37.7549,
            longitude: longitude ? longitude + 0.003 : -122.4494,
            rating: 4.3,
            priceLevel: 1,
            types: ["cafe", "health_food", "juice_bar"],
            placeId: "ChIJd8BlQ2BZwokRAFUEcm_qrcE",
            photoUrl: "https://images.unsplash.com/photo-1570197788417-0e82375c9371?w=400"
          }
        ];

        // Filter based on query if needed (simple text matching for mock data)
        const filteredPlaces = mockPlaces.filter(place => 
          place.name.toLowerCase().includes(query.toLowerCase()) ||
          place.types.some(type => type.toLowerCase().includes(query.toLowerCase())) ||
          query.toLowerCase().includes('restaurant') ||
          query.toLowerCase().includes('food') ||
          query.toLowerCase().includes('cafe')
        );

        const limitedResults = filteredPlaces.slice(0, limit);
        
        console.log(`✅ Places Search: Returning ${limitedResults.length} results`);
        return limitedResults;
        
      } catch (error) {
        console.error('❌ Places Search Error:', error);
        throw new Error('Failed to search places');
      }
    }),
});

export type PlacesRouter = typeof placesRouter;
