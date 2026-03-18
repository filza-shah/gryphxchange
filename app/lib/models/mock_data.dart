class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    required this.rating,
    required this.totalRatings,
  });

  final String id;
  final String name;
  final String email;
  final String? avatar;
  final double rating;
  final int totalRatings;
}

class Listing {
  const Listing({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.isTrade,
    this.tradeFor,
    required this.courseCode,
    required this.semester,
    required this.images,
    required this.sellerId,
    required this.seller,
    required this.createdAt,
    required this.category,
  });

  final String id;
  final String title;
  final String description;
  final double? price;
  final bool isTrade;
  // What the seller wants in return for a trade listing (optional free-text).
  final String? tradeFor;
  final String courseCode;
  final String semester;
  final List<String> images;
  final String sellerId;
  final AppUser seller;
  final DateTime createdAt;
  final String category;
}

enum OfferType { cash, trade }

enum TradeStatus { pending, accepted, rejected, completed }

class Trade {
  const Trade({
    required this.id,
    required this.listingId,
    required this.listing,
    required this.offerType,
    this.cashAmount,
    this.tradeItemId,
    this.tradeItem,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String listingId;
  final Listing listing;
  final OfferType offerType;
  final double? cashAmount;
  final String? tradeItemId;
  final Listing? tradeItem;
  final TradeStatus status;
  final DateTime createdAt;
}

class SafeZone {
  const SafeZone({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
  });

  final int id;
  final String name;
  final double lat;
  final double lng;
}

// mock dataset for local UI/dev flow until api wiring is in.
const AppUser currentUser = AppUser(
  id: 'user-1',
  name: 'Lebron James',
  email: 'ljames@uoguelph.ca',
  rating: 4.8,
  totalRatings: 24,
);

const List<AppUser> mockUsers = <AppUser>[
  AppUser(
    id: 'user-2',
    name: 'Alex Chen',
    email: 'achen@uoguelph.ca',
    rating: 4.9,
    totalRatings: 31,
  ),
  AppUser(
    id: 'user-3',
    name: 'Marcus Rodriguez',
    email: 'mrodriguez@uoguelph.ca',
    rating: 4.7,
    totalRatings: 18,
  ),
  AppUser(
    id: 'user-4',
    name: 'Emily Parker',
    email: 'eparker@uoguelph.ca',
    rating: 5.0,
    totalRatings: 42,
  ),
  AppUser(
    id: 'user-5',
    name: 'Jordan Lee',
    email: 'jlee@uoguelph.ca',
    rating: 4.6,
    totalRatings: 15,
  ),
];

// these are what wishlist matching scans through.
final List<Listing> mockListings = <Listing>[
  Listing(
    id: 'listing-1',
    title: 'Data Structures Textbook',
    description:
        'Like new condition. Used for one semester. All chapters intact, no highlighting.',
    price: 45,
    isTrade: false,
    courseCode: 'CIS*2520',
    semester: 'Winter 2026',
    images: <String>[
      'https://images.unsplash.com/photo-1543002588-bfa74002ed7e?w=400',
    ],
    sellerId: 'user-2',
    seller: mockUsers[0],
    createdAt: DateTime.utc(2026, 2, 28, 10),
    category: 'Textbooks',
  ),
  Listing(
    id: 'listing-2',
    title: 'Scientific Calculator TI-84',
    description:
        'Perfect working condition. Batteries included. Great for MATH courses.',
    price: null,
    isTrade: true,
    tradeFor: 'Physics or Stats textbook',
    courseCode: 'MATH*1200',
    semester: 'Fall 2025',
    images: <String>[
      'https://images.unsplash.com/photo-1509228468518-180dd4864904?w=400',
    ],
    sellerId: 'user-3',
    seller: mockUsers[1],
    createdAt: DateTime.utc(2026, 2, 27, 14, 30),
    category: 'Electronics',
  ),
  Listing(
    id: 'listing-3',
    title: 'Organic Chemistry Lab Manual',
    description:
        'Complete with all worksheets. Minor wear on cover. Essential for CHEM*2700.',
    price: 30,
    isTrade: false,
    courseCode: 'CHEM*2700',
    semester: 'Winter 2026',
    images: <String>[
      'https://images.unsplash.com/photo-1532012197267-da84d127e765?w=400',
    ],
    sellerId: 'user-4',
    seller: mockUsers[2],
    createdAt: DateTime.utc(2026, 2, 26, 9, 15),
    category: 'Lab Materials',
  ),
  Listing(
    id: 'listing-4',
    title: 'Software Engineering Notes Bundle',
    description:
        'Complete lecture notes and study guides for CIS*4030. Helped me get an A+!',
    price: 25,
    isTrade: true,
    tradeFor: 'Any CIS or ENGG notes/textbook',
    courseCode: 'CIS*4030',
    semester: 'Fall 2025',
    images: <String>[
      'https://images.unsplash.com/photo-1586281380349-632531db7ed4?w=400',
    ],
    sellerId: 'user-5',
    seller: mockUsers[3],
    createdAt: DateTime.utc(2026, 2, 25, 16, 45),
    category: 'Study Materials',
  ),
  Listing(
    id: 'listing-5',
    title: 'Biology Microscope Slides Set',
    description:
        'Complete set of 50 prepared slides. Perfect for BIOL*1050 lab.',
    price: 20,
    isTrade: false,
    courseCode: 'BIOL*1050',
    semester: 'Winter 2026',
    images: <String>[
      'https://images.unsplash.com/photo-1576086213369-97a306d36557?w=400',
    ],
    sellerId: 'user-2',
    seller: mockUsers[0],
    createdAt: DateTime.utc(2026, 2, 24, 11, 20),
    category: 'Lab Materials',
  ),
  Listing(
    id: 'listing-6',
    title: 'Python Programming Textbook',
    description:
        'Introduction to Python - 3rd Edition. Excellent condition, barely used.',
    price: 35,
    isTrade: false,
    courseCode: 'CIS*1300',
    semester: 'Fall 2025',
    images: <String>[
      'https://images.unsplash.com/photo-1515879218367-8466d910aaa4?w=400',
    ],
    sellerId: 'user-3',
    seller: mockUsers[1],
    createdAt: DateTime.utc(2026, 2, 23, 13),
    category: 'Textbooks',
  ),
];

// active mock trades power the "Matches" tab signals.
final List<Trade> mockTrades = <Trade>[
  Trade(
    id: 'trade-1',
    listingId: 'listing-2',
    listing: mockListings[1],
    offerType: OfferType.trade,
    tradeItemId: 'listing-1',
    tradeItem: mockListings[0],
    status: TradeStatus.pending,
    createdAt: DateTime.utc(2026, 2, 28, 15),
  ),
  Trade(
    id: 'trade-2',
    listingId: 'listing-4',
    listing: mockListings[3],
    offerType: OfferType.cash,
    cashAmount: 20,
    status: TradeStatus.accepted,
    createdAt: DateTime.utc(2026, 2, 27, 10, 30),
  ),
];

const List<SafeZone> campusSafeZones = <SafeZone>[
  SafeZone(
    id: 1,
    name: 'University Centre - Main Entrance',
    lat: 43.5320,
    lng: -80.2260,
  ),
  SafeZone(
    id: 2,
    name: 'McLaughlin Library - Lobby',
    lat: 43.5315,
    lng: -80.2275,
  ),
  SafeZone(
    id: 3,
    name: 'Science Complex - Atrium',
    lat: 43.5310,
    lng: -80.2250,
  ),
  SafeZone(
    id: 4,
    name: 'Athletic Centre - Front Desk',
    lat: 43.5305,
    lng: -80.2240,
  ),
];