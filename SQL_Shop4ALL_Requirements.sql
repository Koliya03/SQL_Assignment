create database Shop4All;
use Shop4All;

CREATE TABLE category(
category_id BIGINT AUTO_INCREMENT,
category_name VARCHAR(100) UNIQUE NOT NULL,

primary key (category_id)
);

CREATE TABLE Product (
   product_id  BIGINT AUTO_INCREMENT,
   category_id BIGINT NOT NULL,
   product_name VARCHAR(50) NOT NULL,
   product_description VARCHAR(100) NOT NULL,
   
   PRIMARY KEY (product_id),
   FOREIGN KEY (category_id) REFERENCES category(category_id)
);


CREATE TABLE inventory(
inventory_id BIGINT AUTO_INCREMENT,
product_id BIGINT NOT NULL,
available_quantity INT NOT NULL CHECK (available_quantity >= 0),
createdTime DATETIME NOT NULL,
updatedTIME DATETIME NOT NULL,

primary key (inventory_id),
FOREIGN KEY (product_id) REFERENCES Product(product_id)
);


CREATE TABLE Stocks(
stock_Id BIGINT AUTO_INCREMENT,
inventory_id  BIGINT NOT NULL,
stock_quantity INT NOT NULL ,
stock_price DECIMAL(10,2) NOT NULL,
product_price DECIMAL(10,2) NOT NULL,

CONSTRAINT check_stock_values CHECK (stock_quantity > 0 AND stock_price > 0),
PRIMARY KEY(stock_Id),
FOREIGN KEY(inventory_id) REFERENCES inventory(inventory_id)

);


CREATE TABLE Shipping_Address(
   shipping_id CHAR(36),
   street_address VARCHAR(100) NOT NULL,
   city VARCHAR(20)NOT NULL,
   state VARCHAR(20) NOT NULL,
   postal_code INT  CHECK (postal_code >= 0),
   country VARCHAR(30) NOT NULL,
   
   PRIMARY KEY(shipping_id)
);

CREATE TABLE customer(
   customer_id CHAR(36),
   customer_name VARCHAR(50) NOT NULL,
   Email VARCHAR(30) UNIQUE NOT NULL,
   phone_number VARCHAR(12)NOT NULL,
   
   PRIMARY KEY(customer_id),
   CONSTRAINT ck_customer_phone_e164
   CHECK (REGEXP_LIKE(phone_number, '^[+][1-9][0-9]{0,10}$'))
);


CREATE TABLE Customer_Shipping_Addresses(
customer_address_ID CHAR(36),
shipping_id CHAR(36) NOT NULL,
customer_id CHAR(36) NOT NULL,

PRIMARY KEY(customer_address_ID),
foreign key(shipping_id) REFERENCES Shipping_Address(shipping_id),
foreign key(customer_id) REFERENCES customer(customer_id)
);

CREATE TABLE Orders(
   order_id CHAR(36),
   customer_address_ID CHAR(36) NOT NULL,
   order_date datetime NOT NULL,
   order_price DECIMAL(10,2) NOT NULL,
   
   PRIMARY KEY(order_id),
   foreign key(customer_address_ID) REFERENCES Customer_Shipping_Addresses(customer_address_ID)
);


CREATE TABLE Order_items(
   order_id CHAR(36) ,
   stock_Id BIGINT,
   num_of_items INT check(num_of_items>0),
   price_of_items DECIMAL(10,2) NOT NULL,
   
   CONSTRAINT PK_ORDER PRIMARY KEY (order_id,stock_Id),
   foreign key(order_id) REFERENCES Orders(order_id),
   foreign key(stock_Id) REFERENCES Stocks(stock_Id)
);


delimiter //
CREATE PROCEDURE insertCategory(IN categoryname VARCHAR(100))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
	INSERT INTO category(category_name)VALUE(categoryname);
	COMMIT;
END//
  
delimiter //
CREATE PROCEDURE insertNewProduct ( IN product_category BIGINT,IN product_Name VARCHAR(50),IN product_description VARCHAR(100))
	BEGIN
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		ROLLBACK;
		RESIGNAL;
	END;

	START TRANSACTION;
		INSERT INTO Product(
		   category_id,
		   product_name,
		   product_description
		) VALUES
		  ( product_category, product_Name,  product_description );
	COMMIT;
END //


delimiter //
CREATE PROCEDURE insertNewinventory (IN product_id BIGINT)
   BEGIN
   DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
		INSERT INTO inventory(
		product_id,
		available_quantity,
		createdTime,
		updatedTIME

		) VALUES
		( product_id, 0,  NOW(),NOW() );
	COMMIT;
END //

delimiter //
CREATE PROCEDURE addNewStock(IN inventoryID BIGINT,IN stockQuantity BIGINT,IN stockPrice DECIMAL(10,2))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
		INSERT INTO Stocks(
		inventory_id,
		stock_quantity,
		stock_price,
		product_price
		)VALUE
		(inventoryID,stockQuantity,stockPrice,stock_price/stock_quantity);

		UPDATE Inventory
		SET available_quantity = available_quantity + stockQuantity,
			updatedTIME = NOW()
		WHERE inventory_id = inventoryID;
	COMMIT;

END//


delimiter //
CREATE PROCEDURE insertNewCustomer (IN customer_name VARCHAR(50),IN Email VARCHAR(30),IN phone_number VARCHAR(12))
   BEGIN
   DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
		INSERT INTO customer(
        customer_id,
		customer_name,
		Email,
		phone_number
		) VALUES
		( UUID(), customer_name,  Email, phone_number);
	COMMIT;
END //


delimiter //
CREATE PROCEDURE insertNewShippingAddress (
	IN street_address VARCHAR(100),
	IN city VARCHAR(20),
	IN state VARCHAR(20),
	IN postal_code INT,
	IN country VARCHAR(30) )
   BEGIN
   DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;

    START TRANSACTION;
		INSERT INTO Shipping_Address(
        shipping_id,
		street_address,
		city,
        state,
        postal_code,
		country
		) VALUES
		( UUID(), street_address,  city, state,postal_code,country);
	COMMIT;
END //

delimiter //
CREATE PROCEDURE insertcustomerAddress (IN shipping_id CHAR(36),IN customer_id CHAR(36))
   BEGIN
   DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;

    START TRANSACTION;
		INSERT INTO Customer_Shipping_Addresses(
		customer_address_ID,
		shipping_id,
		customer_id 
		) VALUES
		( UUID(), shipping_id,  customer_id);
	COMMIT;
END //

DELIMITER //
CREATE FUNCTION getOrderItemsPrice(stockID BIGINT, numberOfItems INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE productPrice DECIMAL(10,2) DEFAULT 0;
    DECLARE itemsPrice  DECIMAL(10,2);
    SELECT IFNULL(product_price, 0)
      INTO productPrice
    FROM Stocks
    WHERE stock_Id = stockID;

    SET itemsPrice = numberOfItems * productPrice;
    RETURN itemsPrice;
END //
DELIMITER ;

DELIMITER //
CREATE FUNCTION getTotalproductInOrderItems( paraStock_Id BIGINT)
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE totalOfSameProduct INT DEFAULT 0;
    SELECT 
    SUM(orderItemTable.num_of_items) 
      INTO totalOfSameProduct
    FROM Order_items AS orderItemTable
    JOIN Stocks AS stocksTable
    ON stocksTable.stock_Id = orderItemTable.stock_Id 
    WHERE stocksTable.inventory_id = (
    SELECT inventory_id
    FROM Stocks
    WHERE Stocks.stock_Id = paraStock_Id
    )
    GROUP BY stocksTable.inventory_id;
    RETURN totalOfSameProduct;
END //
DELIMITER ;

delimiter //
CREATE PROCEDURE insertnewOrderItems (IN order_id CHAR(36),IN stock_Id BIGINT,IN num_of_items INT )
   BEGIN
   DECLARE INVENTORYID BIGINT;
   DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
		INSERT INTO Order_items(
		order_id,
		stock_Id,
		num_of_items ,
        price_of_items
		) VALUES
		( order_id, stock_Id,  num_of_items, getOrderItemsPrice(stock_Id,num_of_items));
        
        SELECT inventory_id INTO INVENTORYID
        FROM Stocks AS S
        WHERE S.stock_Id = stock_Id;
        UPDATE Inventory
		SET available_quantity = available_quantity - num_of_items,
			updatedTIME = NOW()
		WHERE inventory_id = INVENTORYID;
	COMMIT;
END //

DELIMITER //
CREATE FUNCTION getTotalOrderPrice( orderid CHAR(36))
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE totalOrderPrice DECIMAL(10,2) DEFAULT 0;
    SELECT 
    SUM(price_of_items) 
      INTO totalOrderPrice
    FROM Order_items
    WHERE order_id = orderid;
    RETURN totalOrderPrice;
END //
DELIMITER ;

delimiter //
CREATE PROCEDURE insertnewOrder (IN customerAddress CHAR(36),IN orderPrice DECIMAL(10,2))
   BEGIN
   DECLARE orderID CHAR(36);
   DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
		INSERT INTO Orders(
        order_id,
		customer_address_ID,
		order_date,
		order_price 
		) VALUES
		( UUID(), customerAddress,NOW(),orderPrice);
	COMMIT;
END //

-- REQUREMENT NUMBER 1
DELIMITER //
CREATE FUNCTION getallSoldUnits( inventory_Id BIGINT)
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE totalOfstocks INT DEFAULT 0;
     DECLARE currentQuantity INT DEFAULT 0;
    DECLARE soldUnits INT DEFAULT 0;
    SELECT 
    SUM(stock_quantity) 
      INTO totalOfstocks
    FROM Stocks 
    WHERE Stocks.inventory_id = inventory_Id;
    
    SELECT available_quantity
    INTO currentQuantity
    FROM inventory
    WHERE inventory.inventory_id =inventory_Id;
    
    RETURN totalOfstocks - currentQuantity;
END //
DELIMITER ;

CREATE VIEW v_top_selling_products AS
SELECT 
p.product_id,
p.product_name,
p.product_description,
getallSoldUnits(inv.inventory_id) AS total_units_sold

FROM Product AS p
JOIN inventory AS inv ON p.product_id = inv.inventory_id
ORDER BY DECS;
;

-- Requirement number 2
DELIMITER //
CREATE FUNCTION getAveragePriceOfProduct( categoryParaId BIGINT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
	DECLARE averagePrice DECIMAL(10,2) default 0;
   SELECT AVG(st.product_price) 
   INTO averagePrice
   FROM Stocks AS st
   JOIN inventory AS inv
   ON inv.inventory_id = st.inventory_id
   JOIN Product AS pd
   ON inv.product_id = pd.product_id
   where pd.category_id = categoryParaId;
   RETURN averagePrice;
END //
DELIMITER ;


delimiter //
CREATE PROCEDURE generateMonthlyReport ()
   BEGIN
   DECLARE INVENTORYID BIGINT;
   DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
	SELECT
    YEAR(Orders.order_date) AS Year, 
	MONTH(Orders.order_date) AS Month,
	SUM(Order_items.price_of_items) AS Total_Sales,
    COUNT( DISTINCT  Orders.order_id) AS Order_Count
	FROM Orders 
    JOIN Order_items
    ON Order_items.order_id = Orders.order_id
	GROUP BY YEAR(Orders.order_date), MONTH(Orders.order_date) ;
	COMMIT;
END //


CALL insertCategory('STATIONARY');
CALL insertCategory('ELECTRONIC');
CALL insertCategory('cutleries');
select * from category;

CALL insertNewProduct(1,'Books','CR books for writing purpose');
CALL insertNewProduct(2,'Torch','rechargible torch with super light');
select * from Product;

CALL insertNewinventory(1);
select * from inventory;

CALL addNewStock(1,20,10000);
CALL addNewStock(1,10,12000);
select * from Stocks;

CALL insertNewCustomer('Koliya','koliya@gmail.com','+94715839505');
select * from customer;

CALL insertNewShippingAddress('240 1/2','KADUWELA','COLOMBO',10640,'SRI LANKA');
select * from Shipping_Address;

SET @cust := (SELECT customer_id FROM customer WHERE Email='koliya@gmail.com' ORDER BY customer_id DESC LIMIT 1);
SET @ship := (SELECT shipping_id FROM Shipping_Address
              WHERE street_address='240 1/2' AND city='KADUWELA' AND state='COLOMBO'
                AND postal_code=10640 AND country='SRI LANKA'
              ORDER BY shipping_id DESC LIMIT 1);

CALL insertcustomerAddress(@ship, @cust);
SELECT * FROM Customer_Shipping_Addresses;

SET @custAddr := (SELECT customer_address_ID
                  FROM Customer_Shipping_Addresses
                  WHERE customer_id=@cust AND shipping_id=@ship);

CALL insertnewOrder( @custAddr,2200);
SELECT * FROM Orders;

SET @orderID := (SELECT order_id FROM Orders
              WHERE customer_address_ID= @custAddr);
CALL insertnewOrderItems(@orderID,1,2);
CALL insertnewOrderItems(@orderID,2,1);

select * from order_items;

SELECT * FROM v_top_selling_products;
SELECT getAveragePriceOfProduct(1);
CALL generateMonthlyReport();


select * from v_top_selling_products
-- drop database shop4all

