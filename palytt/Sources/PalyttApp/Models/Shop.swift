//
//  Shop.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation

struct Shop: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let description: String?
    let location: Location
    let phoneNumber: String?
    let website: URL?
    let hours: BusinessHours
    let cuisineTypes: [CuisineType]
    let drinkTypes: [DrinkType]
    let dessertTypes: [DessertType]
    let priceRange: PriceRange
    let rating: Double
    let reviewsCount: Int
    let photosCount: Int
    let menu: [MenuItem]?
    let ownerId: UUID?
    let isVerified: Bool
    let featuredImageURL: URL?
    var isFavorite: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        location: Location,
        phoneNumber: String? = nil,
        website: URL? = nil,
        hours: BusinessHours,
        cuisineTypes: [CuisineType] = [],
        drinkTypes: [DrinkType] = [],
        dessertTypes: [DessertType] = [],
        priceRange: PriceRange = .moderate,
        rating: Double = 0.0,
        reviewsCount: Int = 0,
        photosCount: Int = 0,
        menu: [MenuItem]? = nil,
        ownerId: UUID? = nil,
        isVerified: Bool = false,
        featuredImageURL: URL? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.location = location
        self.phoneNumber = phoneNumber
        self.website = website
        self.hours = hours
        self.cuisineTypes = cuisineTypes
        self.drinkTypes = drinkTypes
        self.dessertTypes = dessertTypes
        self.priceRange = priceRange
        self.rating = rating
        self.reviewsCount = reviewsCount
        self.photosCount = photosCount
        self.menu = menu
        self.ownerId = ownerId
        self.isVerified = isVerified
        self.featuredImageURL = featuredImageURL
        self.isFavorite = isFavorite
    }
}

// MARK: - Business Hours
struct BusinessHours: Codable, Equatable {
    let monday: DayHours?
    let tuesday: DayHours?
    let wednesday: DayHours?
    let thursday: DayHours?
    let friday: DayHours?
    let saturday: DayHours?
    let sunday: DayHours?
    
    struct DayHours: Codable, Equatable {
        let open: String
        let close: String
        let isClosed: Bool
    }
    
    func hoursForToday() -> DayHours? {
        let weekday = Calendar.current.component(.weekday, from: Date())
        switch weekday {
        case 1: return sunday
        case 2: return monday
        case 3: return tuesday
        case 4: return wednesday
        case 5: return thursday
        case 6: return friday
        case 7: return saturday
        default: return nil
        }
    }
    
    // Default hours for shops when hours aren't available
    static let defaultHours = BusinessHours(
        monday: DayHours(open: "09:00", close: "21:00", isClosed: false),
        tuesday: DayHours(open: "09:00", close: "21:00", isClosed: false),
        wednesday: DayHours(open: "09:00", close: "21:00", isClosed: false),
        thursday: DayHours(open: "09:00", close: "21:00", isClosed: false),
        friday: DayHours(open: "09:00", close: "22:00", isClosed: false),
        saturday: DayHours(open: "09:00", close: "22:00", isClosed: false),
        sunday: DayHours(open: "10:00", close: "20:00", isClosed: false)
    )
}

// MARK: - Menu Item
struct MenuItem: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let description: String?
    let price: Decimal
    let category: String
    let imageURL: URL?
    let dietaryInfo: [DietaryPreference]
    let isPopular: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        price: Decimal,
        category: String,
        imageURL: URL? = nil,
        dietaryInfo: [DietaryPreference] = [],
        isPopular: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.price = price
        self.category = category
        self.imageURL = imageURL
        self.dietaryInfo = dietaryInfo
        self.isPopular = isPopular
    }
}

// MARK: - Supporting Types
enum CuisineType: String, CaseIterable, Codable {
    case american = "American"
    case bbq = "BBQ"
    case brazilian = "Brazilian"
    case breakfastBrunch = "Breakfast/Brunch"
    case burgers = "Burgers"
    case cafe = "Cafe"
    case caribbean = "Caribbean"
    case chinese = "Chinese"
    case cuban = "Cuban"
    case deli = "Deli"
    case dessert = "Dessert"
    case ethiopian = "Ethiopian"
    case filipino = "Filipino"
    case french = "French"
    case fusion = "Fusion"
    case greek = "Greek"
    case halal = "Halal"
    case hotPot = "Hot Pot"
    case indonesian = "Indonesian"
    case indian = "Indian"
    case italian = "Italian"
    case japanese = "Japanese"
    case kbbq = "K-BBQ"
    case korean = "Korean"
    case lebanese = "Lebanese"
    case mediterranean = "Mediterranean"
    case mexican = "Mexican"
    case middleEastern = "Middle Eastern"
    case moroccan = "Moroccan"
    case pizza = "Pizza"
    case ramen = "Ramen"
    case salad = "Salad"
    case sandwiches = "Sandwiches"
    case seafood = "Seafood"
    case shabuShabu = "Shabu Shabu"
    case singaporean = "Singaporean"
    case soulFood = "Soul Food"
    case southeastAsian = "Southeast Asian"
    case spanish = "Spanish"
    case steakhouse = "Steakhouse"
    case sushi = "Sushi"
    case tapas = "Tapas"
    case thai = "Thai"
    case turkish = "Turkish"
    case vegan = "Vegan"
    case vegetarian = "Vegetarian"
    case vietnamese = "Vietnamese"
    case other = "Other"
}

enum DrinkType: String, CaseIterable, Codable {
    case coffee = "Coffee"
    case freshJuice = "Fresh Juice"
    case fruitTea = "Fruit Tea"
    case matcha = "Matcha"
    case milkTea = "Milk Tea"
    case smoothie = "Smoothie"
    case tea = "Tea"
}

enum DessertType: String, CaseIterable, Codable {
    case iceCream = "Ice Cream"
    case cake = "Cake"
    case cookies = "Cookies"
    case pastries = "Pastries"
    case chocolate = "Chocolate"
    case donuts = "Donuts"
    case cupcakes = "Cupcakes"
    case macarons = "Macarons"
    case gelato = "Gelato"
    case frozenYogurt = "Frozen Yogurt"
    case pie = "Pie"
    case cheesecake = "Cheesecake"
}

enum PriceRange: Int, CaseIterable, Codable {
    case budget = 1
    case moderate = 2
    case expensive = 3
    case luxury = 4
    
    var symbol: String {
        String(repeating: "$", count: rawValue)
    }
    
    var description: String {
        switch self {
        case .budget: return "Budget-friendly"
        case .moderate: return "Moderate"
        case .expensive: return "Expensive"
        case .luxury: return "Luxury"
        }
    }
}

// MARK: - Shop Review Model
struct ShopReview: Identifiable {
    let id: String
    let authorName: String
    let rating: Int
    let text: String
    let createdAt: Date
} 