-- QuickApp - Initial Database Script (SQL Server)
-- Run this script to create the core schema for MVP

IF DB_ID('QuickApp') IS NULL
BEGIN
    CREATE DATABASE QuickApp;
END
GO

USE QuickApp;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

------------------------------------------------------------
-- 1. Core User Management
------------------------------------------------------------

CREATE TABLE dbo.Users (
    UserId            UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Users PRIMARY KEY DEFAULT NEWID(),
    Email             NVARCHAR(255)   NOT NULL UNIQUE,
    PhoneNumber       NVARCHAR(20)    NULL UNIQUE,
    PasswordHash      NVARCHAR(500)   NOT NULL,
    FirstName         NVARCHAR(100)   NOT NULL,
    LastName          NVARCHAR(100)   NOT NULL,
    UserType          INT             NOT NULL, -- 1:Customer, 2:Supplier, 3:Driver, 4:Admin
    IsActive          BIT             NOT NULL CONSTRAINT DF_Users_IsActive DEFAULT (1),
    IsVerified        BIT             NOT NULL CONSTRAINT DF_Users_IsVerified DEFAULT (0),
    CreatedDate       DATETIME2       NOT NULL CONSTRAINT DF_Users_CreatedDate DEFAULT (SYSUTCDATETIME()),
    LastLoginDate     DATETIME2       NULL,
    ProfileImageUrl   NVARCHAR(500)   NULL,
    PreferredLanguage NVARCHAR(10)    NOT NULL CONSTRAINT DF_Users_Lang DEFAULT ('en')
);
GO

CREATE TABLE dbo.Customers (
    CustomerId            UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Customers PRIMARY KEY,
    DateOfBirth           DATE             NULL,
    Gender                NVARCHAR(20)     NULL,
    LoyaltyPoints         INT              NOT NULL CONSTRAINT DF_Customers_Loyalty DEFAULT (0),
    TotalOrders           INT              NOT NULL CONSTRAINT DF_Customers_TotalOrders DEFAULT (0),
    TotalSpent            DECIMAL(18,2)    NOT NULL CONSTRAINT DF_Customers_TotalSpent DEFAULT (0),
    PreferredPaymentMethod NVARCHAR(50)    NULL,
    MarketingOptIn        BIT              NOT NULL CONSTRAINT DF_Customers_Marketing DEFAULT (0),
    ReferralCode          NVARCHAR(20)     NULL UNIQUE,
    ReferredBy            UNIQUEIDENTIFIER NULL,
    CONSTRAINT FK_Customers_Users FOREIGN KEY (CustomerId) REFERENCES dbo.Users(UserId),
    CONSTRAINT FK_Customers_ReferredBy FOREIGN KEY (ReferredBy) REFERENCES dbo.Customers(CustomerId)
);
GO

CREATE TABLE dbo.Suppliers (
    SupplierId           UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Suppliers PRIMARY KEY,
    BusinessName         NVARCHAR(255)   NOT NULL,
    BusinessType         NVARCHAR(100)   NULL,
    TaxId                NVARCHAR(50)    NULL UNIQUE,
    BusinessLicenseNumber NVARCHAR(100)  NULL,
    BankAccountNumber    NVARCHAR(50)    NULL,
    BankRoutingNumber    NVARCHAR(50)    NULL,
    CommissionRate       DECIMAL(5,2)    NOT NULL CONSTRAINT DF_Suppliers_Commission DEFAULT (10.00),
    IsApproved           BIT             NOT NULL CONSTRAINT DF_Suppliers_IsApproved DEFAULT (0),
    ApprovalDate         DATETIME2       NULL,
    ApprovedBy           UNIQUEIDENTIFIER NULL,
    Rating               DECIMAL(3,2)    NULL,
    TotalProducts        INT             NOT NULL CONSTRAINT DF_Suppliers_TotalProducts DEFAULT (0),
    TotalSales           DECIMAL(18,2)   NOT NULL CONSTRAINT DF_Suppliers_TotalSales DEFAULT (0),
    StoreDescription     NVARCHAR(MAX)   NULL,
    StoreImageUrl        NVARCHAR(500)   NULL,
    ContactEmail         NVARCHAR(255)   NULL,
    ContactPhone         NVARCHAR(20)    NULL,
    WebsiteUrl           NVARCHAR(500)   NULL,
    OperatingHours       NVARCHAR(500)   NULL,
    CONSTRAINT FK_Suppliers_Users FOREIGN KEY (SupplierId) REFERENCES dbo.Users(UserId),
    CONSTRAINT FK_Suppliers_ApprovedBy FOREIGN KEY (ApprovedBy) REFERENCES dbo.Users(UserId)
);
GO

CREATE TABLE dbo.Drivers (
    DriverId             UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Drivers PRIMARY KEY,
    LicenseNumber        NVARCHAR(50)  NOT NULL UNIQUE,
    LicenseExpiryDate    DATE          NOT NULL,
    VehicleType          NVARCHAR(50)  NULL,
    VehicleModel         NVARCHAR(100) NULL,
    VehicleYear          INT           NULL,
    VehicleColor         NVARCHAR(50)  NULL,
    LicensePlate         NVARCHAR(20)  NOT NULL UNIQUE,
    InsuranceExpiryDate  DATE          NULL,
    IsAvailable          BIT           NOT NULL CONSTRAINT DF_Drivers_IsAvailable DEFAULT (1),
    CurrentLatitude      DECIMAL(10,8) NULL,
    CurrentLongitude     DECIMAL(11,8) NULL,
    LastLocationUpdate   DATETIME2     NULL,
    Rating               DECIMAL(3,2)  NULL,
    TotalDeliveries      INT           NOT NULL CONSTRAINT DF_Drivers_TotalDeliveries DEFAULT (0),
    TotalEarnings        DECIMAL(18,2) NOT NULL CONSTRAINT DF_Drivers_TotalEarnings DEFAULT (0),
    CompletionRate       DECIMAL(5,2)  NULL,
    AverageDeliveryTime  INT           NULL,
    IsVerified           BIT           NOT NULL CONSTRAINT DF_Drivers_IsVerified DEFAULT (0),
    EmergencyContactName NVARCHAR(100) NULL,
    EmergencyContactPhone NVARCHAR(20) NULL,
    CONSTRAINT FK_Drivers_Users FOREIGN KEY (DriverId) REFERENCES dbo.Users(UserId)
);
GO

CREATE TABLE dbo.Admins (
    AdminId            UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Admins PRIMARY KEY,
    AdminLevel         INT             NOT NULL CONSTRAINT DF_Admins_Level DEFAULT (1),
    Department         NVARCHAR(100)   NULL,
    EmployeeId         NVARCHAR(50)    NULL UNIQUE,
    CanApproveSuppliers BIT            NOT NULL CONSTRAINT DF_Admins_Approve DEFAULT (0),
    CanManagePayments  BIT             NOT NULL CONSTRAINT DF_Admins_Payments DEFAULT (0),
    CanHandleDisputes  BIT             NOT NULL CONSTRAINT DF_Admins_Disputes DEFAULT (0),
    LastActivityDate   DATETIME2       NULL,
    CONSTRAINT FK_Admins_Users FOREIGN KEY (AdminId) REFERENCES dbo.Users(UserId)
);
GO

------------------------------------------------------------
-- 2. Address Management
------------------------------------------------------------

CREATE TABLE dbo.Addresses (
    AddressId      UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Addresses PRIMARY KEY DEFAULT NEWID(),
    UserId         UNIQUEIDENTIFIER NOT NULL,
    AddressType    INT             NOT NULL, -- 1:Home,2:Work,3:Other
    StreetAddress  NVARCHAR(255)   NOT NULL,
    Apartment      NVARCHAR(50)    NULL,
    City           NVARCHAR(100)   NOT NULL,
    State          NVARCHAR(100)   NOT NULL,
    PostalCode     NVARCHAR(20)    NOT NULL,
    Country        NVARCHAR(100)   NOT NULL,
    Latitude       DECIMAL(10,8)   NULL,
    Longitude      DECIMAL(11,8)   NULL,
    IsDefault      BIT             NOT NULL CONSTRAINT DF_Addresses_IsDefault DEFAULT (0),
    Label          NVARCHAR(50)    NULL,
    CreatedDate    DATETIME2       NOT NULL CONSTRAINT DF_Addresses_Created DEFAULT (SYSUTCDATETIME()),
    IsActive       BIT             NOT NULL CONSTRAINT DF_Addresses_IsActive DEFAULT (1),
    CONSTRAINT FK_Addresses_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId)
);
GO

------------------------------------------------------------
-- 3. Product & Catalog
------------------------------------------------------------

CREATE TABLE dbo.Categories (
    CategoryId        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Categories PRIMARY KEY,
    ParentCategoryId  INT              NULL,
    Name              NVARCHAR(100)    NOT NULL,
    Description       NVARCHAR(500)    NULL,
    ImageUrl          NVARCHAR(500)    NULL,
    DisplayOrder      INT              NOT NULL CONSTRAINT DF_Categories_DisplayOrder DEFAULT (0),
    IsActive          BIT              NOT NULL CONSTRAINT DF_Categories_IsActive DEFAULT (1),
    CreatedDate       DATETIME2        NOT NULL CONSTRAINT DF_Categories_Created DEFAULT (SYSUTCDATETIME()),
    CreatedBy         UNIQUEIDENTIFIER NULL,
    CONSTRAINT FK_Categories_Parent FOREIGN KEY (ParentCategoryId) REFERENCES dbo.Categories(CategoryId),
    CONSTRAINT FK_Categories_CreatedBy FOREIGN KEY (CreatedBy) REFERENCES dbo.Users(UserId)
);
GO

CREATE TABLE dbo.Products (
    ProductId         UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Products PRIMARY KEY DEFAULT NEWID(),
    SupplierId        UNIQUEIDENTIFIER NOT NULL,
    CategoryId        INT              NULL,
    SKU               NVARCHAR(50)     NULL UNIQUE,
    Name              NVARCHAR(255)    NOT NULL,
    Description       NVARCHAR(MAX)    NULL,
    ShortDescription  NVARCHAR(500)    NULL,
    BasePrice         DECIMAL(10,2)    NOT NULL,
    CostPrice         DECIMAL(10,2)    NULL,
    CompareAtPrice    DECIMAL(10,2)    NULL,
    WeightKg          DECIMAL(8,2)     NULL,
    LengthCm          DECIMAL(8,2)     NULL,
    WidthCm           DECIMAL(8,2)     NULL,
    HeightCm          DECIMAL(8,2)     NULL,
    Unit              NVARCHAR(20)     NOT NULL CONSTRAINT DF_Products_Unit DEFAULT ('piece'),
    MinOrderQuantity  INT              NOT NULL CONSTRAINT DF_Products_MinQty DEFAULT (1),
    MaxOrderQuantity  INT              NULL,
    StockQuantity     INT              NOT NULL CONSTRAINT DF_Products_Stock DEFAULT (0),
    LowStockThreshold INT              NOT NULL CONSTRAINT DF_Products_LowStock DEFAULT (10),
    IsActive          BIT              NOT NULL CONSTRAINT DF_Products_IsActive DEFAULT (1),
    IsFeatured        BIT              NOT NULL CONSTRAINT DF_Products_IsFeatured DEFAULT (0),
    RequiresShipping  BIT              NOT NULL CONSTRAINT DF_Products_RequiresShipping DEFAULT (1),
    TaxRate           DECIMAL(5,2)     NULL,
    Rating            DECIMAL(3,2)     NULL,
    TotalReviews      INT              NOT NULL CONSTRAINT DF_Products_TotalReviews DEFAULT (0),
    TotalSold         INT              NOT NULL CONSTRAINT DF_Products_TotalSold DEFAULT (0),
    CreatedDate       DATETIME2        NOT NULL CONSTRAINT DF_Products_Created DEFAULT (SYSUTCDATETIME()),
    UpdatedDate       DATETIME2        NOT NULL CONSTRAINT DF_Products_Updated DEFAULT (SYSUTCDATETIME()),
    CreatedBy         UNIQUEIDENTIFIER NULL,
    UpdatedBy         UNIQUEIDENTIFIER NULL,
    CONSTRAINT FK_Products_Suppliers FOREIGN KEY (SupplierId) REFERENCES dbo.Suppliers(SupplierId),
    CONSTRAINT FK_Products_Categories FOREIGN KEY (CategoryId) REFERENCES dbo.Categories(CategoryId),
    CONSTRAINT FK_Products_CreatedBy FOREIGN KEY (CreatedBy) REFERENCES dbo.Users(UserId),
    CONSTRAINT FK_Products_UpdatedBy FOREIGN KEY (UpdatedBy) REFERENCES dbo.Users(UserId)
);
GO

CREATE TABLE dbo.ProductImages (
    ImageId      UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_ProductImages PRIMARY KEY DEFAULT NEWID(),
    ProductId    UNIQUEIDENTIFIER NOT NULL,
    ImageUrl     NVARCHAR(500)    NOT NULL,
    AltText      NVARCHAR(255)    NULL,
    DisplayOrder INT              NOT NULL CONSTRAINT DF_ProductImages_DisplayOrder DEFAULT (0),
    IsPrimary    BIT              NOT NULL CONSTRAINT DF_ProductImages_IsPrimary DEFAULT (0),
    CreatedDate  DATETIME2        NOT NULL CONSTRAINT DF_ProductImages_Created DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT FK_ProductImages_Products FOREIGN KEY (ProductId) REFERENCES dbo.Products(ProductId)
);
GO

------------------------------------------------------------
-- 4. Orders & Order Items
------------------------------------------------------------

CREATE TABLE dbo.Orders (
    OrderId             UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Orders PRIMARY KEY DEFAULT NEWID(),
    OrderNumber         NVARCHAR(50)     NOT NULL UNIQUE,
    CustomerId          UNIQUEIDENTIFIER NOT NULL,
    OrderStatus         INT              NOT NULL, -- 1:Pending..7:Cancelled
    OrderType           INT              NOT NULL CONSTRAINT DF_Orders_OrderType DEFAULT (1),
    SubtotalAmount      DECIMAL(18,2)    NOT NULL,
    TaxAmount           DECIMAL(18,2)    NOT NULL CONSTRAINT DF_Orders_Tax DEFAULT (0),
    DeliveryFee         DECIMAL(18,2)    NOT NULL CONSTRAINT DF_Orders_DeliveryFee DEFAULT (0),
    DiscountAmount      DECIMAL(18,2)    NOT NULL CONSTRAINT DF_Orders_Discount DEFAULT (0),
    TotalAmount         DECIMAL(18,2)    NOT NULL,
    Currency            NVARCHAR(3)      NOT NULL CONSTRAINT DF_Orders_Currency DEFAULT ('USD'),
    DeliveryAddressId   UNIQUEIDENTIFIER NOT NULL,
    BillingAddressId    UNIQUEIDENTIFIER NULL,
    SpecialInstructions NVARCHAR(MAX)    NULL,
    EstimatedDeliveryTime DATETIME2      NULL,
    ActualDeliveryTime  DATETIME2        NULL,
    OrderDate           DATETIME2        NOT NULL CONSTRAINT DF_Orders_OrderDate DEFAULT (SYSUTCDATETIME()),
    ConfirmedDate       DATETIME2        NULL,
    CreatedBy           UNIQUEIDENTIFIER NULL,
    UpdatedDate         DATETIME2        NOT NULL CONSTRAINT DF_Orders_Updated DEFAULT (SYSUTCDATETIME()),
    UpdatedBy           UNIQUEIDENTIFIER NULL,
    CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerId) REFERENCES dbo.Customers(CustomerId),
    CONSTRAINT FK_Orders_DeliveryAddress FOREIGN KEY (DeliveryAddressId) REFERENCES dbo.Addresses(AddressId),
    CONSTRAINT FK_Orders_BillingAddress FOREIGN KEY (BillingAddressId) REFERENCES dbo.Addresses(AddressId),
    CONSTRAINT FK_Orders_CreatedBy FOREIGN KEY (CreatedBy) REFERENCES dbo.Users(UserId),
    CONSTRAINT FK_Orders_UpdatedBy FOREIGN KEY (UpdatedBy) REFERENCES dbo.Users(UserId)
);
GO

CREATE TABLE dbo.OrderItems (
    OrderItemId        UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_OrderItems PRIMARY KEY DEFAULT NEWID(),
    OrderId            UNIQUEIDENTIFIER NOT NULL,
    ProductId          UNIQUEIDENTIFIER NOT NULL,
    SupplierId         UNIQUEIDENTIFIER NOT NULL,
    Quantity           INT              NOT NULL,
    UnitPrice          DECIMAL(10,2)    NOT NULL,
    TotalPrice         DECIMAL(18,2)    NOT NULL,
    DiscountAmount     DECIMAL(18,2)    NOT NULL CONSTRAINT DF_OrderItems_Discount DEFAULT (0),
    TaxAmount          DECIMAL(18,2)    NOT NULL CONSTRAINT DF_OrderItems_Tax DEFAULT (0),
    SpecialInstructions NVARCHAR(500)   NULL,
    Status             INT              NOT NULL CONSTRAINT DF_OrderItems_Status DEFAULT (1),
    CreatedDate        DATETIME2        NOT NULL CONSTRAINT DF_OrderItems_Created DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT FK_OrderItems_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders(OrderId),
    CONSTRAINT FK_OrderItems_Products FOREIGN KEY (ProductId) REFERENCES dbo.Products(ProductId),
    CONSTRAINT FK_OrderItems_Suppliers FOREIGN KEY (SupplierId) REFERENCES dbo.Suppliers(SupplierId)
);
GO

------------------------------------------------------------
-- 5. Delivery & Driver Tracking
------------------------------------------------------------

CREATE TABLE dbo.Deliveries (
    DeliveryId          UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Deliveries PRIMARY KEY DEFAULT NEWID(),
    OrderId             UNIQUEIDENTIFIER NOT NULL,
    DriverId            UNIQUEIDENTIFIER NULL,
    DeliveryStatus      INT              NOT NULL CONSTRAINT DF_Deliveries_Status DEFAULT (1),
    PickupAddress       NVARCHAR(500)    NULL,
    PickupLatitude      DECIMAL(10,8)    NULL,
    PickupLongitude     DECIMAL(11,8)    NULL,
    DeliveryAddress     NVARCHAR(500)    NULL,
    DeliveryLatitude    DECIMAL(10,8)    NULL,
    DeliveryLongitude   DECIMAL(11,8)    NULL,
    AssignedDate        DATETIME2        NULL,
    PickupDate          DATETIME2        NULL,
    DeliveryDate        DATETIME2        NULL,
    EstimatedDeliveryMinutes INT         NULL,
    ActualDeliveryMinutes    INT         NULL,
    DistanceKm          DECIMAL(8,2)     NULL,
    DeliveryNotes       NVARCHAR(MAX)    NULL,
    RecipientName       NVARCHAR(100)    NULL,
    RecipientSignatureUrl NVARCHAR(500)  NULL,
    DeliveryPhotoUrl    NVARCHAR(500)    NULL,
    Rating              INT              NULL,
    RatingComment       NVARCHAR(MAX)    NULL,
    CreatedDate         DATETIME2        NOT NULL CONSTRAINT DF_Deliveries_Created DEFAULT (SYSUTCDATETIME()),
    UpdatedDate         DATETIME2        NOT NULL CONSTRAINT DF_Deliveries_Updated DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT FK_Deliveries_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders(OrderId),
    CONSTRAINT FK_Deliveries_Drivers FOREIGN KEY (DriverId) REFERENCES dbo.Drivers(DriverId)
);
GO

CREATE TABLE dbo.DriverLocations (
    LocationId      BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DriverLocations PRIMARY KEY,
    DriverId        UNIQUEIDENTIFIER NOT NULL,
    DeliveryId      UNIQUEIDENTIFIER NULL,
    Latitude        DECIMAL(10,8)   NOT NULL,
    Longitude       DECIMAL(11,8)   NOT NULL,
    AccuracyMeters  DECIMAL(6,2)    NULL,
    SpeedKmh        DECIMAL(6,2)    NULL,
    HeadingDegrees  DECIMAL(6,2)    NULL,
    Timestamp       DATETIME2        NOT NULL CONSTRAINT DF_DriverLocations_Timestamp DEFAULT (SYSUTCDATETIME()),
    IsActiveDelivery BIT             NOT NULL CONSTRAINT DF_DriverLocations_IsActive DEFAULT (0),
    CONSTRAINT FK_DriverLocations_Drivers FOREIGN KEY (DriverId) REFERENCES dbo.Drivers(DriverId),
    CONSTRAINT FK_DriverLocations_Deliveries FOREIGN KEY (DeliveryId) REFERENCES dbo.Deliveries(DeliveryId)
);
GO

------------------------------------------------------------
-- 6. Payments & Payouts
------------------------------------------------------------

CREATE TABLE dbo.Payouts (
    PayoutId        UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Payouts PRIMARY KEY DEFAULT NEWID(),
    SupplierId      UNIQUEIDENTIFIER NULL,
    DriverId        UNIQUEIDENTIFIER NULL,
    PayoutType      INT              NOT NULL, -- 1:Supplier, 2:Driver
    PeriodStart     DATE             NOT NULL,
    PeriodEnd       DATE             NOT NULL,
    TotalAmount     DECIMAL(18,2)    NOT NULL,
    CommissionAmount DECIMAL(18,2)   NOT NULL CONSTRAINT DF_Payouts_Commission DEFAULT (0),
    NetAmount       DECIMAL(18,2)    NOT NULL,
    Currency        NVARCHAR(3)      NOT NULL CONSTRAINT DF_Payouts_Currency DEFAULT ('USD'),
    PayoutStatus    INT              NOT NULL CONSTRAINT DF_Payouts_Status DEFAULT (1),
    ScheduledDate   DATE             NULL,
    ProcessedDate   DATETIME2        NULL,
    PaymentMethod   NVARCHAR(50)     NULL,
    ReferenceNumber NVARCHAR(100)    NULL,
    FailureReason   NVARCHAR(500)    NULL,
    CreatedDate     DATETIME2        NOT NULL CONSTRAINT DF_Payouts_Created DEFAULT (SYSUTCDATETIME()),
    ProcessedBy     UNIQUEIDENTIFIER NULL,
    CONSTRAINT FK_Payouts_Suppliers FOREIGN KEY (SupplierId) REFERENCES dbo.Suppliers(SupplierId),
    CONSTRAINT FK_Payouts_Drivers FOREIGN KEY (DriverId) REFERENCES dbo.Drivers(DriverId),
    CONSTRAINT FK_Payouts_ProcessedBy FOREIGN KEY (ProcessedBy) REFERENCES dbo.Users(UserId)
);
GO

CREATE TABLE dbo.Payments (
    PaymentId        UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Payments PRIMARY KEY DEFAULT NEWID(),
    OrderId          UNIQUEIDENTIFIER NULL,
    PayoutId         UNIQUEIDENTIFIER NULL,
    PaymentType      INT              NOT NULL, -- 1:Order,2:SupplierPayout,3:DriverPayout,4:Refund
    PaymentMethod    INT              NULL, -- 1:Card,2:Bank,3:Wallet,5:Cash
    PaymentProvider  NVARCHAR(50)     NULL,
    ProviderPaymentId NVARCHAR(255)   NULL,
    Amount           DECIMAL(18,2)    NOT NULL,
    Currency         NVARCHAR(3)      NOT NULL CONSTRAINT DF_Payments_Currency DEFAULT ('USD'),
    PaymentStatus    INT              NOT NULL, -- 1:Pending..5:Refunded
    PaymentDate      DATETIME2        NULL,
    FailureReason    NVARCHAR(500)    NULL,
    RefundAmount     DECIMAL(18,2)    NOT NULL CONSTRAINT DF_Payments_Refund DEFAULT (0),
    RefundDate       DATETIME2        NULL,
    Metadata         NVARCHAR(MAX)    NULL,
    CreatedDate      DATETIME2        NOT NULL CONSTRAINT DF_Payments_Created DEFAULT (SYSUTCDATETIME()),
    ProcessedBy      UNIQUEIDENTIFIER NULL,
    CONSTRAINT FK_Payments_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders(OrderId),
    CONSTRAINT FK_Payments_Payouts FOREIGN KEY (PayoutId) REFERENCES dbo.Payouts(PayoutId),
    CONSTRAINT FK_Payments_ProcessedBy FOREIGN KEY (ProcessedBy) REFERENCES dbo.Users(UserId)
);
GO

------------------------------------------------------------
-- 7. Discounts & Promotions
------------------------------------------------------------

CREATE TABLE dbo.DiscountCodes (
    DiscountCodeId     UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_DiscountCodes PRIMARY KEY DEFAULT NEWID(),
    Code               NVARCHAR(50)     NOT NULL UNIQUE,
    Description        NVARCHAR(255)    NULL,
    DiscountType       INT              NOT NULL, -- 1:% 2:Fixed 3:FreeShipping
    DiscountValue      DECIMAL(10,2)    NOT NULL,
    MinimumOrderAmount DECIMAL(10,2)    NULL,
    MaximumDiscountAmount DECIMAL(10,2) NULL,
    UsageLimit         INT              NULL,
    UsageCount         INT              NOT NULL CONSTRAINT DF_DiscountCodes_UsageCount DEFAULT (0),
    UserUsageLimit     INT              NOT NULL CONSTRAINT DF_DiscountCodes_UserUsage DEFAULT (1),
    ValidFrom          DATETIME2        NULL,
    ValidTo            DATETIME2        NULL,
    IsActive           BIT              NOT NULL CONSTRAINT DF_DiscountCodes_IsActive DEFAULT (1),
    ApplicableTo       INT              NULL, -- 1:All,2:Products,3:Categories,4:Suppliers
    CreatedBy          UNIQUEIDENTIFIER NULL,
    CreatedDate        DATETIME2        NOT NULL CONSTRAINT DF_DiscountCodes_Created DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT FK_DiscountCodes_CreatedBy FOREIGN KEY (CreatedBy) REFERENCES dbo.Users(UserId)
);
GO

CREATE TABLE dbo.DiscountCodeProducts (
    DiscountCodeId UNIQUEIDENTIFIER NOT NULL,
    ProductId      UNIQUEIDENTIFIER NOT NULL,
    CONSTRAINT PK_DiscountCodeProducts PRIMARY KEY (DiscountCodeId, ProductId),
    CONSTRAINT FK_DiscountCodeProducts_DiscountCodes FOREIGN KEY (DiscountCodeId) REFERENCES dbo.DiscountCodes(DiscountCodeId),
    CONSTRAINT FK_DiscountCodeProducts_Products FOREIGN KEY (ProductId) REFERENCES dbo.Products(ProductId)
);
GO

------------------------------------------------------------
-- 8. Reviews & Ratings
------------------------------------------------------------

CREATE TABLE dbo.Reviews (
    ReviewId      UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Reviews PRIMARY KEY DEFAULT NEWID(),
    OrderId       UNIQUEIDENTIFIER NULL,
    ProductId     UNIQUEIDENTIFIER NULL,
    SupplierId    UNIQUEIDENTIFIER NULL,
    DriverId      UNIQUEIDENTIFIER NULL,
    CustomerId    UNIQUEIDENTIFIER NOT NULL,
    ReviewType    INT              NOT NULL, --1:Product,2:Supplier,3:Driver,4:Order
    Rating        INT              NOT NULL,
    Title         NVARCHAR(255)    NULL,
    Comment       NVARCHAR(MAX)    NULL,
    IsVerified    BIT              NOT NULL CONSTRAINT DF_Reviews_IsVerified DEFAULT (0),
    IsPublished   BIT              NOT NULL CONSTRAINT DF_Reviews_IsPublished DEFAULT (1),
    HelpfulVotes  INT              NOT NULL CONSTRAINT DF_Reviews_HelpfulVotes DEFAULT (0),
    CreatedDate   DATETIME2        NOT NULL CONSTRAINT DF_Reviews_Created DEFAULT (SYSUTCDATETIME()),
    UpdatedDate   DATETIME2        NULL,
    CONSTRAINT FK_Reviews_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders(OrderId),
    CONSTRAINT FK_Reviews_Products FOREIGN KEY (ProductId) REFERENCES dbo.Products(ProductId),
    CONSTRAINT FK_Reviews_Suppliers FOREIGN KEY (SupplierId) REFERENCES dbo.Suppliers(SupplierId),
    CONSTRAINT FK_Reviews_Drivers FOREIGN KEY (DriverId) REFERENCES dbo.Drivers(DriverId),
    CONSTRAINT FK_Reviews_Customers FOREIGN KEY (CustomerId) REFERENCES dbo.Customers(CustomerId)
);
GO

------------------------------------------------------------
-- 9. Analytics & Logging
------------------------------------------------------------

CREATE TABLE dbo.AnalyticsEvents (
    EventId     BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_AnalyticsEvents PRIMARY KEY,
    UserId      UNIQUEIDENTIFIER NULL,
    EventType   NVARCHAR(100)   NOT NULL,
    SessionId   NVARCHAR(255)   NULL,
    EventData   NVARCHAR(MAX)   NULL,
    IpAddress   NVARCHAR(45)    NULL,
    UserAgent   NVARCHAR(500)   NULL,
    Url         NVARCHAR(1000)  NULL,
    Referrer    NVARCHAR(1000)  NULL,
    Timestamp   DATETIME2       NOT NULL CONSTRAINT DF_AnalyticsEvents_Timestamp DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT FK_AnalyticsEvents_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId)
);
GO

CREATE TABLE dbo.SystemLogs (
    LogId        BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SystemLogs PRIMARY KEY,
    LogLevel     INT            NOT NULL,
    Category     NVARCHAR(100)  NULL,
    Message      NVARCHAR(MAX)  NOT NULL,
    Exception    NVARCHAR(MAX)  NULL,
    UserId       UNIQUEIDENTIFIER NULL,
    IpAddress    NVARCHAR(45)   NULL,
    UserAgent    NVARCHAR(500)  NULL,
    RequestId    NVARCHAR(255)  NULL,
    AdditionalData NVARCHAR(MAX) NULL,
    Timestamp    DATETIME2      NOT NULL CONSTRAINT DF_SystemLogs_Timestamp DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT FK_SystemLogs_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId)
);
GO

CREATE TABLE dbo.NotificationLogs (
    NotificationId     UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_NotificationLogs PRIMARY KEY DEFAULT NEWID(),
    UserId             UNIQUEIDENTIFIER NOT NULL,
    NotificationType   INT              NOT NULL,
    Title              NVARCHAR(255)    NULL,
    Message            NVARCHAR(MAX)    NOT NULL,
    Data               NVARCHAR(MAX)    NULL,
    IsSent             BIT              NOT NULL CONSTRAINT DF_NotificationLogs_IsSent DEFAULT (0),
    SentDate           DATETIME2        NULL,
    DeliveredDate      DATETIME2        NULL,
    ReadDate           DATETIME2        NULL,
    FailureReason      NVARCHAR(500)    NULL,
    Provider           NVARCHAR(50)     NULL,
    ProviderMessageId  NVARCHAR(255)    NULL,
    CreatedDate        DATETIME2        NOT NULL CONSTRAINT DF_NotificationLogs_Created DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT FK_NotificationLogs_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId)
);
GO

------------------------------------------------------------
-- 10. Indexes
------------------------------------------------------------

CREATE INDEX IX_Users_UserType ON dbo.Users(UserType);
CREATE INDEX IX_Customers_TotalOrders ON dbo.Customers(TotalOrders);
CREATE INDEX IX_Suppliers_IsApproved ON dbo.Suppliers(IsApproved);
CREATE INDEX IX_Products_Supplier_Category ON dbo.Products(SupplierId, CategoryId);
CREATE INDEX IX_Products_IsActive ON dbo.Products(IsActive);
CREATE INDEX IX_Orders_Customer_Status ON dbo.Orders(CustomerId, OrderStatus);
CREATE INDEX IX_Orders_OrderDate ON dbo.Orders(OrderDate);
CREATE INDEX IX_Deliveries_Driver_Status ON dbo.Deliveries(DriverId, DeliveryStatus);
CREATE INDEX IX_Payments_Order ON dbo.Payments(OrderId);
CREATE INDEX IX_Payouts_Supplier_Period ON dbo.Payouts(SupplierId, PeriodStart, PeriodEnd);

PRINT 'QuickApp core database schema created successfully.';
GO

