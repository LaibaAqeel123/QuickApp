# QuickApp - Database ERD (Entity Relationship Diagram)

## Overview
This document outlines the complete database schema for the QuickApp e-commerce delivery platform. The schema supports multiple user types (Customers, Suppliers, Drivers, Admins) with role-based access and comprehensive order management.

## Database Schema Design

### Core User Management Tables

#### Users (Base table for all user types)
```sql
Users {
  UserId (PK, GUID) - Unique identifier
  Email (NVARCHAR(255), UNIQUE, NOT NULL) - User email
  PhoneNumber (NVARCHAR(20), UNIQUE) - Phone number
  PasswordHash (NVARCHAR(500), NOT NULL) - Hashed password
  FirstName (NVARCHAR(100), NOT NULL) - First name
  LastName (NVARCHAR(100), NOT NULL) - Last name
  UserType (INT, NOT NULL) - 1:Customer, 2:Supplier, 3:Driver, 4:Admin
  IsActive (BIT, DEFAULT 1) - Account status
  IsVerified (BIT, DEFAULT 0) - Email/phone verification
  CreatedDate (DATETIME2, DEFAULT GETUTCDATE()) - Registration date
  LastLoginDate (DATETIME2) - Last login timestamp
  ProfileImageUrl (NVARCHAR(500)) - Profile picture URL
  PreferredLanguage (NVARCHAR(10), DEFAULT 'en') - Language preference
}
```

#### Customers (Extension of Users)
```sql
Customers {
  CustomerId (PK, FK -> Users.UserId) - Customer identifier
  DateOfBirth (DATE) - Customer birth date
  Gender (NVARCHAR(20)) - Gender
  LoyaltyPoints (INT, DEFAULT 0) - Loyalty program points
  TotalOrders (INT, DEFAULT 0) - Total order count
  TotalSpent (DECIMAL(18,2), DEFAULT 0) - Total amount spent
  PreferredPaymentMethod (NVARCHAR(50)) - Default payment method
  MarketingOptIn (BIT, DEFAULT 0) - Marketing email consent
  ReferralCode (NVARCHAR(20), UNIQUE) - Unique referral code
  ReferredBy (FK -> Customers.CustomerId) - Who referred this customer
}
```

#### Suppliers (Extension of Users)
```sql
Suppliers {
  SupplierId (PK, FK -> Users.UserId) - Supplier identifier
  BusinessName (NVARCHAR(255), NOT NULL) - Business name
  BusinessType (NVARCHAR(100)) - Type of business
  TaxId (NVARCHAR(50), UNIQUE) - Tax identification number
  BusinessLicenseNumber (NVARCHAR(100)) - Business license
  BankAccountNumber (NVARCHAR(50)) - Bank account for payouts
  BankRoutingNumber (NVARCHAR(50)) - Bank routing number
  CommissionRate (DECIMAL(5,2), DEFAULT 10.00) - Commission percentage
  IsApproved (BIT, DEFAULT 0) - Admin approval status
  ApprovalDate (DATETIME2) - When supplier was approved
  ApprovedBy (FK -> Users.UserId) - Admin who approved
  Rating (DECIMAL(3,2)) - Average supplier rating
  TotalProducts (INT, DEFAULT 0) - Total products listed
  TotalSales (DECIMAL(18,2), DEFAULT 0) - Total sales amount
  StoreDescription (NTEXT) - Store description
  StoreImageUrl (NVARCHAR(500)) - Store banner image
  ContactEmail (NVARCHAR(255)) - Business contact email
  ContactPhone (NVARCHAR(20)) - Business contact phone
  WebsiteUrl (NVARCHAR(500)) - Supplier website
  OperatingHours (NVARCHAR(500)) - JSON string of operating hours
}
```

#### Drivers (Extension of Users)
```sql
Drivers {
  DriverId (PK, FK -> Users.UserId) - Driver identifier
  LicenseNumber (NVARCHAR(50), UNIQUE, NOT NULL) - Driver's license
  LicenseExpiryDate (DATE, NOT NULL) - License expiry
  VehicleType (NVARCHAR(50)) - Type of vehicle (bike, car, van)
  VehicleModel (NVARCHAR(100)) - Vehicle model
  VehicleYear (INT) - Vehicle manufacturing year
  VehicleColor (NVARCHAR(50)) - Vehicle color
  LicensePlate (NVARCHAR(20), UNIQUE) - Vehicle license plate
  InsuranceExpiryDate (DATE) - Vehicle insurance expiry
  IsAvailable (BIT, DEFAULT 1) - Current availability status
  CurrentLatitude (DECIMAL(10,8)) - Current GPS latitude
  CurrentLongitude (DECIMAL(11,8)) - Current GPS longitude
  LastLocationUpdate (DATETIME2) - Last GPS update time
  Rating (DECIMAL(3,2)) - Average driver rating
  TotalDeliveries (INT, DEFAULT 0) - Total deliveries completed
  TotalEarnings (DECIMAL(18,2), DEFAULT 0) - Total earnings
  CompletionRate (DECIMAL(5,2)) - Order completion percentage
  AverageDeliveryTime (INT) - Average delivery time in minutes
  IsVerified (BIT, DEFAULT 0) - Background verification status
  EmergencyContactName (NVARCHAR(100)) - Emergency contact name
  EmergencyContactPhone (NVARCHAR(20)) - Emergency contact phone
}
```

#### Admins (Extension of Users)
```sql
Admins {
  AdminId (PK, FK -> Users.UserId) - Admin identifier
  AdminLevel (INT, DEFAULT 1) - Admin privilege level
  Department (NVARCHAR(100)) - Admin department
  EmployeeId (NVARCHAR(50), UNIQUE) - Company employee ID
  CanApproveSuppliers (BIT, DEFAULT 0) - Supplier approval permission
  CanManagePayments (BIT, DEFAULT 0) - Payment management permission
  CanHandleDisputes (BIT, DEFAULT 0) - Dispute handling permission
  LastActivityDate (DATETIME2) - Last admin activity
}
```

### Address Management

#### Addresses
```sql
Addresses {
  AddressId (PK, GUID) - Unique address identifier
  UserId (FK -> Users.UserId) - Associated user
  AddressType (INT) - 1:Home, 2:Work, 3:Other
  StreetAddress (NVARCHAR(255), NOT NULL) - Street address
  Apartment (NVARCHAR(50)) - Apartment/suite number
  City (NVARCHAR(100), NOT NULL) - City
  State (NVARCHAR(100), NOT NULL) - State/Province
  PostalCode (NVARCHAR(20), NOT NULL) - Postal/ZIP code
  Country (NVARCHAR(100), NOT NULL) - Country
  Latitude (DECIMAL(10,8)) - GPS latitude
  Longitude (DECIMAL(11,8)) - GPS longitude
  IsDefault (BIT, DEFAULT 0) - Default address flag
  Label (NVARCHAR(50)) - Custom address label
  CreatedDate (DATETIME2, DEFAULT GETUTCDATE()) - Creation date
  IsActive (BIT, DEFAULT 1) - Active status
}
```

### Product Management

#### Categories
```sql
Categories {
  CategoryId (PK, INT, IDENTITY) - Category identifier
  ParentCategoryId (FK -> Categories.CategoryId) - Parent category
  Name (NVARCHAR(100), NOT NULL) - Category name
  Description (NVARCHAR(500)) - Category description
  ImageUrl (NVARCHAR(500)) - Category image
  DisplayOrder (INT, DEFAULT 0) - Display order
  IsActive (BIT, DEFAULT 1) - Active status
  CreatedDate (DATETIME2, DEFAULT GETUTCDATE()) - Creation date
  CreatedBy (FK -> Users.UserId) - User who created
}
```

#### Products
```sql
Products {
  ProductId (PK, GUID) - Unique product identifier
  SupplierId (FK -> Suppliers.SupplierId, NOT NULL) - Product supplier
  CategoryId (FK -> Categories.CategoryId) - Product category
  SKU (NVARCHAR(50), UNIQUE) - Stock keeping unit
  Name (NVARCHAR(255), NOT NULL) - Product name
  Description (NTEXT) - Product description
  ShortDescription (NVARCHAR(500)) - Short description
  BasePrice (DECIMAL(10,2), NOT NULL) - Base selling price
  CostPrice (DECIMAL(10,2)) - Supplier cost price
  CompareAtPrice (DECIMAL(10,2)) - Original/compare price
  Weight (DECIMAL(8,2)) - Product weight in kg
  Length (DECIMAL(8,2)) - Product length in cm
  Width (DECIMAL(8,2)) - Product width in cm
  Height (DECIMAL(8,2)) - Product height in cm
  Unit (NVARCHAR(20), DEFAULT 'piece') - Unit of measurement
  MinOrderQuantity (INT, DEFAULT 1) - Minimum order quantity
  MaxOrderQuantity (INT) - Maximum order quantity
  StockQuantity (INT, DEFAULT 0) - Current stock
  LowStockThreshold (INT, DEFAULT 10) - Low stock alert threshold
  IsActive (BIT, DEFAULT 1) - Product active status
  IsFeatured (BIT, DEFAULT 0) - Featured product flag
  IsDigital (BIT, DEFAULT 0) - Digital product flag
  RequiresShipping (BIT, DEFAULT 1) - Requires physical shipping
  TaxRate (DECIMAL(5,2)) - Tax rate percentage
  Rating (DECIMAL(3,2)) - Average product rating
  TotalReviews (INT, DEFAULT 0) - Total review count
  TotalSold (INT, DEFAULT 0) - Total units sold
  CreatedDate (DATETIME2, DEFAULT GETUTCDATE()) - Creation date
  UpdatedDate (DATETIME2, DEFAULT GETUTCDATE()) - Last update date
  CreatedBy (FK -> Users.UserId) - User who created
  UpdatedBy (FK -> Users.UserId) - User who last updated
}
```

#### ProductImages
```sql
ProductImages {
  ImageId (PK, GUID) - Image identifier
  ProductId (FK -> Products.ProductId) - Associated product
  ImageUrl (NVARCHAR(500), NOT NULL) - Image URL
  AltText (NVARCHAR(255)) - Alt text for accessibility
  DisplayOrder (INT, DEFAULT 0) - Display order
  IsPrimary (BIT, DEFAULT 0) - Primary image flag
  CreatedDate (DATETIME2, DEFAULT GETUTCDATE()) - Upload date
}
```

### Order Management

#### Orders
```sql
Orders {
  OrderId (PK, GUID) - Unique order identifier
  OrderNumber (NVARCHAR(50), UNIQUE, NOT NULL) - Human-readable order number
  CustomerId (FK -> Customers.CustomerId, NOT NULL) - Customer who placed order
  OrderStatus (INT, NOT NULL) - Status enum (1:Pending, 2:Confirmed, 3:Preparing, 4:Ready, 5:OutForDelivery, 6:Delivered, 7:Cancelled)
  OrderType (INT, DEFAULT 1) - 1:Standard, 2:Express, 3:Scheduled
  SubtotalAmount (DECIMAL(18,2), NOT NULL) - Sum of all items
  TaxAmount (DECIMAL(18,2), DEFAULT 0) - Total tax
  DeliveryFee (DECIMAL(18,2), DEFAULT 0) - Delivery charges
  DiscountAmount (DECIMAL(18,2), DEFAULT 0) - Total discounts applied
  TotalAmount (DECIMAL(18,2), NOT NULL) - Final amount
  Currency (NVARCHAR(3), DEFAULT 'USD') - Currency code
  DeliveryAddressId (FK -> Addresses.AddressId) - Delivery address
  BillingAddressId (FK -> Addresses.AddressId) - Billing address
  SpecialInstructions (NTEXT) - Customer delivery instructions
  EstimatedDeliveryTime (DATETIME2) - Estimated delivery datetime
  ActualDeliveryTime (DATETIME2) - Actual delivery datetime
  OrderDate (DATETIME2, DEFAULT GETUTCDATE()) - Order placement date
  ConfirmedDate (DATETIME2) - Order confirmation date
  CreatedBy (FK -> Users.UserId) - User who created order
  UpdatedDate (DATETIME2, DEFAULT GETUTCDATE()) - Last update date
  UpdatedBy (FK -> Users.UserId) - User who last updated
}
```

#### OrderItems
```sql
OrderItems {
  OrderItemId (PK, GUID) - Order item identifier
  OrderId (FK -> Orders.OrderId, NOT NULL) - Associated order
  ProductId (FK -> Products.ProductId, NOT NULL) - Ordered product
  SupplierId (FK -> Suppliers.SupplierId, NOT NULL) - Product supplier
  Quantity (INT, NOT NULL) - Ordered quantity
  UnitPrice (DECIMAL(10,2), NOT NULL) - Price per unit at time of order
  TotalPrice (DECIMAL(18,2), NOT NULL) - Line total (quantity * unit price)
  DiscountAmount (DECIMAL(18,2), DEFAULT 0) - Line item discount
  TaxAmount (DECIMAL(18,2), DEFAULT 0) - Line item tax
  SpecialInstructions (NVARCHAR(500)) - Item-specific instructions
  Status (INT, DEFAULT 1) - 1:Pending, 2:Confirmed, 3:Preparing, 4:Ready, 5:Cancelled
  CreatedDate (DATETIME2, DEFAULT GETUTCDATE()) - Creation date
}
```

### Delivery Management

#### Deliveries
```sql
Deliveries {
  DeliveryId (PK, GUID) - Delivery identifier
  OrderId (FK -> Orders.OrderId, NOT NULL) - Associated order
  DriverId (FK -> Drivers.DriverId) - Assigned driver
  DeliveryStatus (INT, DEFAULT 1) - 1:Assigned, 2:PickedUp, 3:InTransit, 4:Delivered, 5:Failed
  PickupAddress (NVARCHAR(500)) - Pickup location details
  PickupLatitude (DECIMAL(10,8)) - Pickup GPS latitude
  PickupLongitude (DECIMAL(11,8)) - Pickup GPS longitude
  DeliveryAddress (NVARCHAR(500)) - Delivery location details
  DeliveryLatitude (DECIMAL(10,8)) - Delivery GPS latitude
  DeliveryLongitude (DECIMAL(11,8)) - Delivery GPS longitude
  AssignedDate (DATETIME2) - When driver was assigned
  PickupDate (DATETIME2) - When order was picked up
  DeliveryDate (DATETIME2) - When order was delivered
  EstimatedDeliveryTime (INT) - Estimated delivery time in minutes
  ActualDeliveryTime (INT) - Actual delivery time in minutes
  Distance (DECIMAL(8,2)) - Delivery distance in km
  DeliveryNotes (NTEXT) - Delivery notes from driver
  RecipientName (NVARCHAR(100)) - Person who received delivery
  RecipientSignature (NVARCHAR(500)) - Signature image URL
  DeliveryPhoto (NVARCHAR(500)) - Delivery confirmation photo URL
  Rating (INT) - Customer rating (1-5)
  RatingComment (NTEXT) - Customer feedback
  CreatedDate (DATETIME2, DEFAULT GETUTCDATE()) - Creation date
  UpdatedDate (DATETIME2, DEFAULT GETUTCDATE()) - Last update date
}
```

#### DriverLocations (Real-time tracking)
```sql
DriverLocations {
  LocationId (PK, BIGINT, IDENTITY) - Location record ID
  DriverId (FK -> Drivers.DriverId, NOT NULL) - Driver identifier
  DeliveryId (FK -> Deliveries.DeliveryId) - Associated delivery (if active)
  Latitude (DECIMAL(10,8), NOT NULL) - GPS latitude
  Longitude (DECIMAL(11,8), NOT NULL) - GPS longitude
  Accuracy (DECIMAL(6,2)) - GPS accuracy in meters
  Speed (DECIMAL(6,2)) - Speed in km/h
  Heading (DECIMAL(6,2)) - Direction in degrees
  Timestamp (DATETIME2, DEFAULT GETUTCDATE()) - Location timestamp
  IsActiveDelivery (BIT, DEFAULT 0) - Whether this is during active delivery
}
```

### Payment Management

#### Payments
```sql
Payments {
  PaymentId (PK, GUID) - Payment identifier
  OrderId (FK -> Orders.OrderId) - Associated order (NULL for payouts)
  PayoutId (FK -> Payouts.PayoutId) - Associated payout (NULL for charges)
  PaymentType (INT, NOT NULL) - 1:OrderPayment, 2:SupplierPayout, 3:DriverPayout, 4:Refund
  PaymentMethod (INT) - 1:CreditCard, 2:DebitCard, 3:BankTransfer, 4:Wallet, 5:Cash
  PaymentProvider (NVARCHAR(50)) - Stripe, PayPal, etc.
  ProviderPaymentId (NVARCHAR(255)) - External payment provider ID
  Amount (DECIMAL(18,2), NOT NULL) - Payment amount
  Currency (NVARCHAR(3), DEFAULT 'USD') - Currency code
  PaymentStatus (INT, NOT NULL) - 1:Pending, 2:Processing, 3:Completed, 4:Failed, 5:Refunded
  PaymentDate (DATETIME2) - When payment was processed
  FailureReason (NVARCHAR(500)) - Failure reason if failed
  RefundAmount (DECIMAL(18,2), DEFAULT 0) - Refunded amount
  RefundDate (DATETIME2) - Refund date
  Metadata (NTEXT) - Additional payment metadata (JSON)
  CreatedDate (DATETIME2, DEFAULT GETUTCDATE()) - Creation date
  ProcessedBy (FK -> Users.UserId) - User who processed payment
}
```

#### Payouts
```sql
Payouts {
  PayoutId (PK, GUID) - Payout identifier
  SupplierId (FK -> Suppliers.SupplierId) - Supplier payout
  DriverId (FK -> Drivers.DriverId) - Driver payout
  PayoutType (INT, NOT NULL) - 1:Supplier, 2:Driver
  PeriodStart (DATE, NOT NULL) - Payout period start
  PeriodEnd (DATE, NOT NULL) - Payout period end
  TotalAmount (DECIMAL(18,2), NOT NULL) - Total payout amount
  CommissionAmount (DECIMAL(18,2), DEFAULT 0) - Platform commission
  NetAmount (DECIMAL(18,2), NOT NULL) - Net payout amount
  Currency (NVARCHAR(3), DEFAULT 'USD') - Currency code
  PayoutStatus (INT, DEFAULT 1) - 1:Pending, 2:Processing, 3:Completed, 4:Failed
  ScheduledDate (DATE) - Scheduled payout date
  ProcessedDate (DATETIME2) - Actual payout date
  PaymentMethod (NVARCHAR(50)) - Bank transfer, check, etc.
  ReferenceNumber (NVARCHAR(100)) - Bank reference number
  FailureReason (NVARCHAR(500)) - Failure reason if failed
  CreatedDate (DATETIME2, DEFAULT GETUTCDATE()) - Creation date
  ProcessedBy (FK -> Users.UserId) - Admin who processed
}
```

### Discount & Promotion Management

#### DiscountCodes
```sql
DiscountCodes {
  DiscountCodeId (PK, GUID) - Discount code identifier
  Code (NVARCHAR(50), UNIQUE, NOT NULL) - Discount code
  Description (NVARCHAR(255)) - Code description
  DiscountType (INT, NOT NULL) - 1:Percentage, 2:FixedAmount, 3:FreeShipping
  DiscountValue (DECIMAL(10,2), NOT NULL) - Discount amount/percentage
  MinimumOrderAmount (DECIMAL(10,2)) - Minimum order value required
  MaximumDiscountAmount (DECIMAL(10,2)) - Maximum discount cap
  UsageLimit (INT) - Total usage limit
  UsageCount (INT, DEFAULT 0) - Current usage count
  UserUsageLimit (INT, DEFAULT 1) - Usage limit per user
  ValidFrom (DATETIME2) - Valid from date
  ValidTo (DATETIME2) - Valid to date
  IsActive (BIT, DEFAULT 1) - Active status
  ApplicableTo (INT) - 1:AllProducts, 2:SpecificProducts, 3:SpecificCategories, 4:SpecificSuppliers
  CreatedBy (FK -> Users.UserId) - Who created the code
  CreatedDate (DATETIME2, DEFAULT GETUTCDATE()) - Creation date
}
```

#### DiscountCodeProducts (Many-to-many relationship)
```sql
DiscountCodeProducts {
  DiscountCodeId (FK -> DiscountCodes.DiscountCodeId) - Discount code
  ProductId (FK -> Products.ProductId) - Applicable product
  PRIMARY KEY (DiscountCodeId, ProductId)
}
```

### Review & Rating System

#### Reviews
```sql
Reviews {
  ReviewId (PK, GUID) - Review identifier
  OrderId (FK -> Orders.OrderId, NOT NULL) - Associated order
  ProductId (FK -> Products.ProductId) - Product being reviewed
  SupplierId (FK -> Suppliers.SupplierId) - Supplier being reviewed
  DriverId (FK -> Drivers.DriverId) - Driver being reviewed
  CustomerId (FK -> Customers.CustomerId, NOT NULL) - Customer who wrote review
  ReviewType (INT, NOT NULL) - 1:Product, 2:Supplier, 3:Driver, 4:Order
  Rating (INT, NOT NULL) - Rating 1-5 stars
  Title (NVARCHAR(255)) - Review title
  Comment (NTEXT) - Review comment
  IsVerified (BIT, DEFAULT 0) - Verified purchase review
  IsPublished (BIT, DEFAULT 1) - Review published status
  HelpfulVotes (INT, DEFAULT 0) - Helpful vote count
  CreatedDate (DATETIME2, DEFAULT GETUTCDATE()) - Review date
  UpdatedDate (DATETIME2) - Last update date
}
```

### Analytics & Reporting

#### AnalyticsEvents
```sql
AnalyticsEvents {
  EventId (PK, BIGINT, IDENTITY) - Event identifier
  EventType (NVARCHAR(100), NOT NULL) - Event type (page_view, order_placed, etc.)
  UserId (FK -> Users.UserId) - Associated user
  SessionId (NVARCHAR(255)) - User session identifier
  EventData (NTEXT) - Event data (JSON)
  IpAddress (NVARCHAR(45)) - User IP address
  UserAgent (NVARCHAR(500)) - Browser/device info
  Url (NVARCHAR(1000)) - Page URL
  Referrer (NVARCHAR(1000)) - Referrer URL
  Timestamp (DATETIME2, DEFAULT GETUTCDATE()) - Event timestamp
}
```

### System Management

#### SystemLogs
```sql
SystemLogs {
  LogId (PK, BIGINT, IDENTITY) - Log entry identifier
  LogLevel (INT, NOT NULL) - 1:Debug, 2:Info, 3:Warning, 4:Error, 5:Critical
  Category (NVARCHAR(100)) - Log category (API, Database, Payment, etc.)
  Message (NTEXT, NOT NULL) - Log message
  Exception (NTEXT) - Exception details if applicable
  UserId (FK -> Users.UserId) - Associated user
  IpAddress (NVARCHAR(45)) - IP address
  UserAgent (NVARCHAR(500)) - User agent
  RequestId (NVARCHAR(255)) - Request correlation ID
  AdditionalData (NTEXT) - Additional context data (JSON)
  Timestamp (DATETIME2, DEFAULT GETUTCDATE()) - Log timestamp
}
```

#### NotificationLogs
```sql
NotificationLogs {
  NotificationId (PK, GUID) - Notification identifier
  UserId (FK -> Users.UserId, NOT NULL) - Target user
  NotificationType (INT, NOT NULL) - 1:Email, 2:SMS, 3:Push, 4:InApp
  Title (NVARCHAR(255)) - Notification title
  Message (NTEXT, NOT NULL) - Notification message
  Data (NTEXT) - Additional data (JSON)
  IsSent (BIT, DEFAULT 0) - Delivery status
  SentDate (DATETIME2) - When notification was sent
  DeliveredDate (DATETIME2) - When notification was delivered
  ReadDate (DATETIME2) - When notification was read
  FailureReason (NVARCHAR(500)) - Failure reason if failed
  Provider (NVARCHAR(50)) - Notification provider
  ProviderMessageId (NVARCHAR(255)) - Provider message ID
  CreatedDate (DATETIME2, DEFAULT GETUTCDATE()) - Creation date
}
```

## Key Relationships Summary

1. **Users** → **Customers/Suppliers/Drivers/Admins** (1:1 inheritance)
2. **Customers** → **Orders** (1:many)
3. **Orders** → **OrderItems** (1:many)
4. **OrderItems** → **Products** (many:1)
5. **Products** → **Suppliers** (many:1)
6. **Orders** → **Deliveries** (1:1)
7. **Deliveries** → **Drivers** (many:1)
8. **Orders** → **Payments** (1:many)
9. **Suppliers/Drivers** → **Payouts** (1:many)
10. **Users** → **Addresses** (1:many)
11. **Products** → **Categories** (many:1)
12. **Products** → **ProductImages** (1:many)
13. **Orders/Customers** → **Reviews** (1:many)
14. **DiscountCodes** → **DiscountCodeProducts** (many:many)

## Database Design Principles

- **Normalization**: Database is in 3NF to reduce redundancy
- **Indexing**: Primary keys, foreign keys, and frequently queried columns indexed
- **Constraints**: Foreign key constraints, check constraints, and unique constraints implemented
- **Data Types**: Appropriate data types chosen for performance and storage efficiency
- **Audit Fields**: CreatedDate, UpdatedDate, CreatedBy, UpdatedBy fields for audit trails
- **Soft Deletes**: IsActive flags instead of hard deletes for data integrity
- **Extensibility**: JSON fields for flexible data storage where needed
