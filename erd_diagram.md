# QuickApp - Visual ERD Diagram

## Mermaid ERD Diagram

```mermaid
erDiagram
    %% Core User Management
    Users {
        GUID UserId PK
        NVARCHAR(255) Email UK
        NVARCHAR(20) PhoneNumber UK
        NVARCHAR(500) PasswordHash
        NVARCHAR(100) FirstName
        NVARCHAR(100) LastName
        INT UserType
        BIT IsActive
        BIT IsVerified
        DATETIME2 CreatedDate
        DATETIME2 LastLoginDate
        NVARCHAR(500) ProfileImageUrl
        NVARCHAR(10) PreferredLanguage
    }

    Customers {
        GUID CustomerId PK,FK
        DATE DateOfBirth
        NVARCHAR(20) Gender
        INT LoyaltyPoints
        INT TotalOrders
        DECIMAL(18,2) TotalSpent
        NVARCHAR(50) PreferredPaymentMethod
        BIT MarketingOptIn
        NVARCHAR(20) ReferralCode UK
        GUID ReferredBy FK
    }

    Suppliers {
        GUID SupplierId PK,FK
        NVARCHAR(255) BusinessName
        NVARCHAR(100) BusinessType
        NVARCHAR(50) TaxId UK
        NVARCHAR(100) BusinessLicenseNumber
        NVARCHAR(50) BankAccountNumber
        NVARCHAR(50) BankRoutingNumber
        DECIMAL(5,2) CommissionRate
        BIT IsApproved
        DATETIME2 ApprovalDate
        GUID ApprovedBy FK
        DECIMAL(3,2) Rating
        INT TotalProducts
        DECIMAL(18,2) TotalSales
        NTEXT StoreDescription
        NVARCHAR(500) StoreImageUrl
        NVARCHAR(255) ContactEmail
        NVARCHAR(20) ContactPhone
        NVARCHAR(500) WebsiteUrl
        NVARCHAR(500) OperatingHours
    }

    Drivers {
        GUID DriverId PK,FK
        NVARCHAR(50) LicenseNumber UK
        DATE LicenseExpiryDate
        NVARCHAR(50) VehicleType
        NVARCHAR(100) VehicleModel
        INT VehicleYear
        NVARCHAR(50) VehicleColor
        NVARCHAR(20) LicensePlate UK
        DATE InsuranceExpiryDate
        BIT IsAvailable
        DECIMAL(10,8) CurrentLatitude
        DECIMAL(11,8) CurrentLongitude
        DATETIME2 LastLocationUpdate
        DECIMAL(3,2) Rating
        INT TotalDeliveries
        DECIMAL(18,2) TotalEarnings
        DECIMAL(5,2) CompletionRate
        INT AverageDeliveryTime
        BIT IsVerified
        NVARCHAR(100) EmergencyContactName
        NVARCHAR(20) EmergencyContactPhone
    }

    Admins {
        GUID AdminId PK,FK
        INT AdminLevel
        NVARCHAR(100) Department
        NVARCHAR(50) EmployeeId UK
        BIT CanApproveSuppliers
        BIT CanManagePayments
        BIT CanHandleDisputes
        DATETIME2 LastActivityDate
    }

    %% Address Management
    Addresses {
        GUID AddressId PK
        GUID UserId FK
        INT AddressType
        NVARCHAR(255) StreetAddress
        NVARCHAR(50) Apartment
        NVARCHAR(100) City
        NVARCHAR(100) State
        NVARCHAR(20) PostalCode
        NVARCHAR(100) Country
        DECIMAL(10,8) Latitude
        DECIMAL(11,8) Longitude
        BIT IsDefault
        NVARCHAR(50) Label
        DATETIME2 CreatedDate
        BIT IsActive
    }

    %% Product Management
    Categories {
        INT CategoryId PK
        INT ParentCategoryId FK
        NVARCHAR(100) Name
        NVARCHAR(500) Description
        NVARCHAR(500) ImageUrl
        INT DisplayOrder
        BIT IsActive
        DATETIME2 CreatedDate
        GUID CreatedBy FK
    }

    Products {
        GUID ProductId PK
        GUID SupplierId FK
        INT CategoryId FK
        NVARCHAR(50) SKU UK
        NVARCHAR(255) Name
        NTEXT Description
        NVARCHAR(500) ShortDescription
        DECIMAL(10,2) BasePrice
        DECIMAL(10,2) CostPrice
        DECIMAL(10,2) CompareAtPrice
        DECIMAL(8,2) Weight
        DECIMAL(8,2) Length
        DECIMAL(8,2) Width
        DECIMAL(8,2) Height
        NVARCHAR(20) Unit
        INT MinOrderQuantity
        INT MaxOrderQuantity
        INT StockQuantity
        INT LowStockThreshold
        BIT IsActive
        BIT IsFeatured
        BIT IsDigital
        BIT RequiresShipping
        DECIMAL(5,2) TaxRate
        DECIMAL(3,2) Rating
        INT TotalReviews
        INT TotalSold
        DATETIME2 CreatedDate
        DATETIME2 UpdatedDate
        GUID CreatedBy FK
        GUID UpdatedBy FK
    }

    ProductImages {
        GUID ImageId PK
        GUID ProductId FK
        NVARCHAR(500) ImageUrl
        NVARCHAR(255) AltText
        INT DisplayOrder
        BIT IsPrimary
        DATETIME2 CreatedDate
    }

    %% Order Management
    Orders {
        GUID OrderId PK
        GUID OrderNumber UK
        GUID CustomerId FK
        INT OrderStatus
        INT OrderType
        DECIMAL(18,2) SubtotalAmount
        DECIMAL(18,2) TaxAmount
        DECIMAL(18,2) DeliveryFee
        DECIMAL(18,2) DiscountAmount
        DECIMAL(18,2) TotalAmount
        NVARCHAR(3) Currency
        GUID DeliveryAddressId FK
        GUID BillingAddressId FK
        NTEXT SpecialInstructions
        DATETIME2 EstimatedDeliveryTime
        DATETIME2 ActualDeliveryTime
        DATETIME2 OrderDate
        DATETIME2 ConfirmedDate
        GUID CreatedBy FK
        DATETIME2 UpdatedDate
        GUID UpdatedBy FK
    }

    OrderItems {
        GUID OrderItemId PK
        GUID OrderId FK
        GUID ProductId FK
        GUID SupplierId FK
        INT Quantity
        DECIMAL(10,2) UnitPrice
        DECIMAL(18,2) TotalPrice
        DECIMAL(18,2) DiscountAmount
        DECIMAL(18,2) TaxAmount
        NVARCHAR(500) SpecialInstructions
        INT Status
        DATETIME2 CreatedDate
    }

    %% Delivery Management
    Deliveries {
        GUID DeliveryId PK
        GUID OrderId FK
        GUID DriverId FK
        INT DeliveryStatus
        NVARCHAR(500) PickupAddress
        DECIMAL(10,8) PickupLatitude
        DECIMAL(11,8) PickupLongitude
        NVARCHAR(500) DeliveryAddress
        DECIMAL(10,8) DeliveryLatitude
        DECIMAL(11,8) DeliveryLongitude
        DATETIME2 AssignedDate
        DATETIME2 PickupDate
        DATETIME2 DeliveryDate
        INT EstimatedDeliveryTime
        INT ActualDeliveryTime
        DECIMAL(8,2) Distance
        NTEXT DeliveryNotes
        NVARCHAR(100) RecipientName
        NVARCHAR(500) RecipientSignature
        NVARCHAR(500) DeliveryPhoto
        INT Rating
        NTEXT RatingComment
        DATETIME2 CreatedDate
        DATETIME2 UpdatedDate
    }

    DriverLocations {
        BIGINT LocationId PK
        GUID DriverId FK
        GUID DeliveryId FK
        DECIMAL(10,8) Latitude
        DECIMAL(11,8) Longitude
        DECIMAL(6,2) Accuracy
        DECIMAL(6,2) Speed
        DECIMAL(6,2) Heading
        DATETIME2 Timestamp
        BIT IsActiveDelivery
    }

    %% Payment Management
    Payments {
        GUID PaymentId PK
        GUID OrderId FK
        GUID PayoutId FK
        INT PaymentType
        INT PaymentMethod
        NVARCHAR(50) PaymentProvider
        NVARCHAR(255) ProviderPaymentId
        DECIMAL(18,2) Amount
        NVARCHAR(3) Currency
        INT PaymentStatus
        DATETIME2 PaymentDate
        NVARCHAR(500) FailureReason
        DECIMAL(18,2) RefundAmount
        DATETIME2 RefundDate
        NTEXT Metadata
        DATETIME2 CreatedDate
        GUID ProcessedBy FK
    }

    Payouts {
        GUID PayoutId PK
        GUID SupplierId FK
        GUID DriverId FK
        INT PayoutType
        DATE PeriodStart
        DATE PeriodEnd
        DECIMAL(18,2) TotalAmount
        DECIMAL(18,2) CommissionAmount
        DECIMAL(18,2) NetAmount
        NVARCHAR(3) Currency
        INT PayoutStatus
        DATE ScheduledDate
        DATETIME2 ProcessedDate
        NVARCHAR(50) PaymentMethod
        NVARCHAR(100) ReferenceNumber
        NVARCHAR(500) FailureReason
        DATETIME2 CreatedDate
        GUID ProcessedBy FK
    }

    %% Discount & Promotion Management
    DiscountCodes {
        GUID DiscountCodeId PK
        NVARCHAR(50) Code UK
        NVARCHAR(255) Description
        INT DiscountType
        DECIMAL(10,2) DiscountValue
        DECIMAL(10,2) MinimumOrderAmount
        DECIMAL(10,2) MaximumDiscountAmount
        INT UsageLimit
        INT UsageCount
        INT UserUsageLimit
        DATETIME2 ValidFrom
        DATETIME2 ValidTo
        BIT IsActive
        INT ApplicableTo
        GUID CreatedBy FK
        DATETIME2 CreatedDate
    }

    DiscountCodeProducts {
        GUID DiscountCodeId PK,FK
        GUID ProductId PK,FK
    }

    %% Review & Rating System
    Reviews {
        GUID ReviewId PK
        GUID OrderId FK
        GUID ProductId FK
        GUID SupplierId FK
        GUID DriverId FK
        GUID CustomerId FK
        INT ReviewType
        INT Rating
        NVARCHAR(255) Title
        NTEXT Comment
        BIT IsVerified
        BIT IsPublished
        INT HelpfulVotes
        DATETIME2 CreatedDate
        DATETIME2 UpdatedDate
    }

    %% Analytics & Reporting
    AnalyticsEvents {
        BIGINT EventId PK
        GUID UserId FK
        NVARCHAR(100) EventType
        NVARCHAR(255) SessionId
        NTEXT EventData
        NVARCHAR(45) IpAddress
        NVARCHAR(500) UserAgent
        NVARCHAR(1000) Url
        NVARCHAR(1000) Referrer
        DATETIME2 Timestamp
    }

    %% System Management
    SystemLogs {
        BIGINT LogId PK
        INT LogLevel
        NVARCHAR(100) Category
        NTEXT Message
        NTEXT Exception
        GUID UserId FK
        NVARCHAR(45) IpAddress
        NVARCHAR(500) UserAgent
        NVARCHAR(255) RequestId
        NTEXT AdditionalData
        DATETIME2 Timestamp
    }

    NotificationLogs {
        GUID NotificationId PK
        GUID UserId FK
        INT NotificationType
        NVARCHAR(255) Title
        NTEXT Message
        NTEXT Data
        BIT IsSent
        DATETIME2 SentDate
        DATETIME2 DeliveredDate
        DATETIME2 ReadDate
        NVARCHAR(500) FailureReason
        NVARCHAR(50) Provider
        NVARCHAR(255) ProviderMessageId
        DATETIME2 CreatedDate
    }

    %% Relationships
    Users ||--o{ Customers : "extends"
    Users ||--o{ Suppliers : "extends"
    Users ||--o{ Drivers : "extends"
    Users ||--o{ Admins : "extends"

    Users ||--o{ Addresses : "has"
    Customers ||--o{ Customers : "refers"

    Users ||--o{ Categories : "creates"
    Suppliers ||--o{ Products : "owns"
    Categories ||--o{ Products : "contains"
    Products ||--o{ ProductImages : "has"

    Customers ||--o{ Orders : "places"
    Orders ||--o{ OrderItems : "contains"
    Products ||--o{ OrderItems : "ordered in"
    Suppliers ||--o{ OrderItems : "fulfills"

    Orders ||--|| Deliveries : "has"
    Drivers ||--o{ Deliveries : "delivers"
    Deliveries ||--o{ DriverLocations : "tracks"

    Orders ||--o{ Payments : "paid by"
    Suppliers ||--o{ Payouts : "receives"
    Drivers ||--o{ Payouts : "receives"
    Users ||--o{ Payments : "processed by"
    Users ||--o{ Payouts : "processed by"

    DiscountCodes ||--o{ DiscountCodeProducts : "applies to"
    Products ||--o{ DiscountCodeProducts : "discounted"

    Orders ||--o{ Reviews : "reviewed in"
    Products ||--o{ Reviews : "reviewed"
    Suppliers ||--o{ Reviews : "reviewed"
    Drivers ||--o{ Reviews : "reviewed"
    Customers ||--o{ Reviews : "writes"

    Users ||--o{ AnalyticsEvents : "generates"
    Users ||--o{ SystemLogs : "appears in"
    Users ||--o{ NotificationLogs : "receives"

    Addresses ||--o{ Orders : "delivery address"
    Addresses ||--o{ Orders : "billing address"
```

## ASCII Art ERD Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              QUICKAPP DATABASE ERD                              │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│     USERS       │       │   CUSTOMERS     │       │   SUPPLIERS     │
│─────────────────│       │─────────────────│       │─────────────────│
│ UserId (PK)     │◄──────┼─ CustomerId (PK)│       │ SupplierId (PK) │
│ Email           │       │ DateOfBirth     │       │ BusinessName    │
│ PhoneNumber     │       │ LoyaltyPoints   │       │ BusinessType    │
│ PasswordHash    │       │ TotalOrders     │       │ TaxId           │
│ FirstName       │       │ TotalSpent      │       │ CommissionRate  │
│ LastName        │       │ ReferralCode    │       │ IsApproved      │
│ UserType        │       │ ReferredBy (FK) │◄─────┐│ Rating          │
│ IsActive        │       └─────────────────┘      │└─────────────────┘
│ IsVerified      │                               │
│ CreatedDate     │                               │
└─────────────────┘                               │
                                                  │
┌─────────────────┐       ┌─────────────────┐      │
│    DRIVERS      │       │     ADMINS      │      │
│─────────────────│       │─────────────────│      │
│ DriverId (PK)   │       │ AdminId (PK)    │      │
│ LicenseNumber   │       │ AdminLevel      │      │
│ VehicleType     │       │ Department      │      │
│ IsAvailable     │       │ CanApproveSup.  │      │
│ CurrentLat/Lng  │       │ LastActivityDate│      │
│ Rating          │       └─────────────────┘      │
│ TotalEarnings   │                               │
└─────────────────┘                               │
                                                  │
┌─────────────────┐                               │
│   ADDRESSES     │                               │
│─────────────────│                               │
│ AddressId (PK)  │◄─────────────────────────────┐│
│ UserId (FK)     │                               ││
│ StreetAddress   │                               ││
│ City, State     │                               ││
│ PostalCode      │                               ││
│ Latitude/Long.  │                               ││
│ IsDefault       │                               ││
└─────────────────┘                               ││
                                                  ││
┌─────────────────┐       ┌─────────────────┐      ││
│  CATEGORIES     │       │    PRODUCTS     │      ││
│─────────────────│       │─────────────────│      ││
│ CategoryId (PK) │◄──────┼─ CategoryId (FK)│      ││
│ Name            │       │ ProductId (PK)  │◄────┘│
│ Description     │       │ SupplierId (FK) │      │
│ IsActive        │       │ SKU             │      │
└─────────────────┘       │ Name            │      │
                          │ BasePrice       │      │
                          │ StockQuantity   │      │
                          │ Rating          │      │
                          └─────────────────┘      │
                                                   │
┌─────────────────┐       ┌─────────────────┐      │
│ PRODUCT IMAGES  │       │     ORDERS      │      │
│─────────────────│       │─────────────────│      │
│ ImageId (PK)    │       │ OrderId (PK)    │◄────┐│
│ ProductId (FK)  │       │ OrderNumber     │     ││
│ ImageUrl        │       │ CustomerId (FK) │     ││
│ IsPrimary       │       │ OrderStatus     │     ││
└─────────────────┘       │ TotalAmount     │     ││
                          │ OrderDate       │     ││
                          │ DeliveryAddr(FK)│◄───┐││
                          └─────────────────┘    │││
                                                 │││
┌─────────────────┐       ┌─────────────────┐     │││
│  ORDER ITEMS    │       │   DELIVERIES    │     │││
│─────────────────│       │─────────────────│     │││
│ OrderItemId(PK) │       │ DeliveryId (PK) │     │││
│ OrderId (FK)    │◄─────┐│ OrderId (FK)    │◄───┐│││
│ ProductId (FK)  │     ││ DriverId (FK)   │    ││││
│ SupplierId (FK) │     ││ DeliveryStatus  │    ││││
│ Quantity        │     ││ PickupLat/Lng   │    ││││
│ UnitPrice       │     ││ DeliveryLat/Lng │    ││││
│ TotalPrice      │     ││ DeliveryDate    │    ││││
└─────────────────┘     │││ Rating          │    ││││
                        ││└─────────────────┘    ││││
                        ││                      ││││
┌─────────────────┐     ││  ┌─────────────────┐ ││││
│   PAYMENTS      │     ││  │ DRIVER LOCATIONS│ ││││
│─────────────────│     ││  │─────────────────│ ││││
│ PaymentId (PK)  │     ││  │ LocationId (PK) │ ││││
│ OrderId (FK)    │◄───┐││  │ DriverId (FK)   │◄┘││││
│ Amount          │    │││  │ DeliveryId (FK) │  ││││
│ PaymentStatus   │    │││  │ Latitude/Long.  │  ││││
│ PaymentProvider │    │││  │ Speed/Heading   │  ││││
│ RefundAmount    │    │││  │ Timestamp       │  ││││
└─────────────────┘    │││  └─────────────────┘  ││││
                       │││                       ││││
┌─────────────────┐    │││  ┌─────────────────┐  ││││
│   PAYOUTS       │    │││  │    REVIEWS      │  ││││
│─────────────────│    │││  │─────────────────│  ││││
│ PayoutId (PK)   │    │││  │ ReviewId (PK)   │  ││││
│ SupplierId (FK) │◄──┘││  │ OrderId (FK)    │◄─┘│││
│ DriverId (FK)   │    ││  │ ProductId (FK)  │  │││
│ TotalAmount     │    ││  │ Rating          │  │││
│ NetAmount       │    ││  │ Comment         │  │││
│ PayoutStatus    │    ││  │ CreatedDate     │  │││
└─────────────────┘    ││  └─────────────────┘  │││
                       ││                       │││
┌─────────────────┐    ││  ┌─────────────────┐  │││
│ DISCOUNT CODES  │    ││  │ ANALYTICS EVENTS│ │││
│─────────────────│    ││  │─────────────────│ │││
│ DiscountCodeId  │    ││  │ EventId (PK)    │ │││
│ Code            │    ││  │ UserId (FK)     │◄┘││
│ DiscountType    │    ││  │ EventType       │  ││
│ DiscountValue   │    ││  │ EventData       │  ││
│ UsageLimit      │    ││  │ Timestamp       │  ││
└─────────────────┘    ││  └─────────────────┘  ││
                       ││                       ││
┌─────────────────┐    ││  ┌─────────────────┐  ││
│ DISCOUNT PROD.  │    ││  │  SYSTEM LOGS    │  ││
│─────────────────│    ││  │─────────────────│  ││
│ DiscountCodeId  │◄──┘│  │ LogId (PK)      │  ││
│ ProductId       │    │  │ LogLevel        │  ││
└─────────────────┘    │  │ Category        │  ││
                       │  │ Message         │  ││
                       │  │ UserId (FK)     │◄┘│
                       │  │ Timestamp       │  ││
                       │  └─────────────────┘  ││
                       │                       ││
                       │  ┌─────────────────┐  ││
                       │  │NOTIFICATION LOGS│  ││
                       │  │─────────────────│  ││
                       │  │ NotificationId  │  ││
                       │  │ UserId (FK)     │◄─┘│
                       │  │ NotificationType│  ││
                       │  │ Title           │  ││
                       │  │ Message         │  ││
                       │  │ IsSent          │  ││
                       │  │ SentDate        │  ││
                       │  └─────────────────┘  ││
                       └───────────────────────┘│
                                                │
                                                └───────────────────────────────

LEGEND:
═══════ One-to-One Relationship
─────── One-to-Many Relationship
═══════ Many-to-Many Relationship
(PK)   Primary Key
(FK)   Foreign Key
```

## How to Use These Diagrams

### Mermaid Diagram
1. **Copy the Mermaid code** above
2. **Paste into any Mermaid renderer**:
   - GitHub/GitLab (supports Mermaid natively)
   - Online editors like mermaid.live
   - VS Code with Mermaid extension
   - Draw.io with Mermaid import

### ASCII Diagram
- **Visual representation** for documentation
- **Easy to read** relationships and cardinalities
- **Print-friendly** for offline reference

### Key Relationships Summary

**Inheritance Pattern:**
- Users → Customers/Suppliers/Drivers/Admins (1:1)

**Core Business Flow:**
- Customers → Orders → OrderItems → Products
- Orders → Deliveries → Drivers
- Orders → Payments
- Suppliers/Drivers → Payouts

**Supporting Entities:**
- Users → Addresses (1:many)
- Products → Categories (many:1)
- Products → ProductImages (1:many)
- Orders → Reviews (1:many)

This ERD diagram provides a complete visual representation of your QuickApp database schema with all 25+ tables and their relationships clearly defined.
