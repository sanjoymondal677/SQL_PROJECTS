CREATE TABLE Orders (
    Order_ID VARCHAR(10) PRIMARY KEY,
    Customer_ID VARCHAR(10),
    Order_Date TIMESTAMP,
    Route_ID VARCHAR(10),
    Warehouse_ID VARCHAR(10),
    Order_Amount DECIMAL(10,2),
    Delivery_Type VARCHAR(20),
    Payment_Mode VARCHAR(20)
);

select * from Orders;

CREATE TABLE Delivery_Agents (
    Agent_ID VARCHAR(10) PRIMARY KEY,
    Agent_Name VARCHAR(100),
    Zone VARCHAR(100),
    Zone_Country VARCHAR(100),
    Experience_Years DECIMAL(4,1),
    Avg_Rating DECIMAL(3,1)
);

select * from Delivery_Agents;

CREATE TABLE Routes (
    Route_ID VARCHAR(10) PRIMARY KEY,
    Source_City VARCHAR(100),
    Source_Country VARCHAR(100),
    Destination_City VARCHAR(100),
    Destination_Country VARCHAR(100),
    Distance_KM INT,
    Avg_Transit_Time_Hours DECIMAL(5,1)
);

select * from Routes;


CREATE TABLE Warehouses (
    Warehouse_ID VARCHAR(10) PRIMARY KEY,
    City VARCHAR(100),
    Country VARCHAR(100),
    Capacity_per_day INT,
    Manager_Name VARCHAR(100)
);

select * from Warehouses;

CREATE TABLE Shipments (
    Shipment_ID VARCHAR(10) PRIMARY KEY,
    Order_ID VARCHAR(10),
    Agent_ID VARCHAR(10),
    Route_ID VARCHAR(10),
    Warehouse_ID VARCHAR(10),
    Pickup_Date TIMESTAMP,
    Delivery_Date TIMESTAMP,
    Delivery_Status VARCHAR(30),
    Delay_Hours DECIMAL(5,1),
    Delivery_Feedback VARCHAR(20),
    Delay_Reason VARCHAR(50),
    Expected_Delivery_Date TIMESTAMP,

    FOREIGN KEY (Order_ID) REFERENCES Orders(Order_ID),
    FOREIGN KEY (Agent_ID) REFERENCES Delivery_Agents(Agent_ID),
    FOREIGN KEY (Route_ID) REFERENCES Routes(Route_ID),
    FOREIGN KEY (Warehouse_ID) REFERENCES Warehouses(Warehouse_ID)
);

select * from Shipments;
--1. Identify and delete duplicate Order_ID or Shipment_ID records.
SELECT
    Order_ID,
    COUNT(*)
FROM Orders
GROUP BY Order_ID
HAVING COUNT(*) > 1;

SELECT
    Shipment_ID,
    COUNT(*)
FROM Shipments
GROUP BY Shipment_ID
HAVING COUNT(*) > 1;

-- 2.Replace null or missing Delay_Hours values in the Shipments Table with the average delay for that Route_ID.
-- .Check whether any NULL values exist
SELECT *
FROM Shipments
WHERE Delay_Hours IS NULL;

-- .See the average delay for each route
/*
SELECT
    Route_ID,
    ROUND(AVG(Delay_Hours), 2) AS Avg_Delay
FROM Shipments
WHERE Delay_Hours IS NOT NULL
GROUP BY Route_ID
ORDER BY Route_ID;
*/

-- .Update NULL values
/*UPDATE Shipments s
SET Delay_Hours = avg_data.avg_delay
FROM (
    SELECT
        Route_ID,
        AVG(Delay_Hours) AS avg_delay
    FROM Shipments
    WHERE Delay_Hours IS NOT NULL
    GROUP BY Route_ID
) avg_data
WHERE s.Route_ID = avg_data.Route_ID
  AND s.Delay_Hours IS NULL;
*/

-- 3.Convert all date columns (Order_Date, Pickup_Date, Delivery_Date) into YYYY-MM-DD HH:MM:SS format using SQL date functions.
-- Check Current Data Type
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'orders'
   OR table_name = 'shipments';

-- Display Dates in YYYY-MM-DD HH:MM:SS Format
-- Orders Table
SELECT
    Order_ID,
    TO_CHAR(Order_Date, 'YYYY-MM-DD HH24:MI:SS') AS Formatted_Order_Date
FROM Orders;

-- Shipments Table
SELECT
    Shipment_ID,
    TO_CHAR(Pickup_Date, 'YYYY-MM-DD HH24:MI:SS') AS Formatted_Pickup_Date,
    TO_CHAR(Delivery_Date, 'YYYY-MM-DD HH24:MI:SS') AS Formatted_Delivery_Date
FROM Shipments;

-- 4.Ensure that no Delivery_Date occurs before Pickup_Date (flag such records).
SELECT
    Shipment_ID,
    Pickup_Date,
    Delivery_Date,
    CASE
        WHEN Delivery_Date < Pickup_Date THEN 'Invalid'
        ELSE 'Valid'
    END AS Date_Status
FROM Shipments;
/*
Shipment records were validated to ensure that Delivery_Date does not occur before Pickup_Date.
A CASE expression was used to flag records as Valid or Invalid, helping identify potential data quality issues.
*/


-- 5.Validate referential integrity between Orders, Routes, Warehouses, and Shipments.

SELECT
    (SELECT COUNT(*)
     FROM Shipments s
     LEFT JOIN Orders o
     ON s.Order_ID = o.Order_ID
     WHERE o.Order_ID IS NULL) AS Invalid_Order_References,

    (SELECT COUNT(*)
     FROM Shipments s
     LEFT JOIN Routes r
     ON s.Route_ID = r.Route_ID
     WHERE r.Route_ID IS NULL) AS Invalid_Route_References,

    (SELECT COUNT(*)
     FROM Shipments s
     LEFT JOIN Warehouses w
     ON s.Warehouse_ID = w.Warehouse_ID
     WHERE w.Warehouse_ID IS NULL) AS Invalid_Warehouse_References,

    (SELECT COUNT(*)
     FROM Shipments s
     LEFT JOIN Delivery_Agents a
     ON s.Agent_ID = a.Agent_ID
     WHERE a.Agent_ID IS NULL) AS Invalid_Agent_References;
-- If rows are returned, those shipments have an invalid
/*Referential integrity checks confirmed that all shipment records correctly reference
existing orders, routes, warehouses, and delivery agents.No invalid references were detected.*/

-- Task 2: Delivery Delay Analysis

-- 1.Calculate delivery delay (in hours) for each shipment using Delivery_Date – Pickup_Date.
SELECT
    Shipment_ID,
    Pickup_Date,
    Delivery_Date,
    ROUND(
        EXTRACT(EPOCH FROM (Delivery_Date - Pickup_Date)) / 3600,
        2
    ) AS Delivery_Delay_Hours
FROM Shipments;
-- Delivery_Date - Pickup_Date
/*
-Returns the time interval between the two timestamps
-EXTRACT(EPOCH FROM ...) - Converts the interval into total seconds.
-/ 3600 - Converts seconds into hours.
-ROUND(...,2) - Rounds the answer to 2 decimal places.
*/

-- 2.Find the Top 10 delayed routes based on average delay hours.
SELECT
    r.Route_ID,
    r.Source_City,
    r.Destination_City,
    ROUND(AVG(s.Delay_Hours), 2) AS Avg_Delay_Hours
FROM Shipments s
JOIN Routes r
    ON s.Route_ID = r.Route_ID
GROUP BY
    r.Route_ID,
    r.Source_City,
    r.Destination_City
ORDER BY Avg_Delay_Hours DESC
LIMIT 10;

-- 3.Use SQL window functions to rank shipments by delay within each Warehouse_ID.
SELECT
    Shipment_ID,
    Warehouse_ID,
    Delay_Hours,
    RANK() OVER (
        PARTITION BY Warehouse_ID --PARTITION BY Warehouse_ID Creates separate groups for each warehouse.
        ORDER BY Delay_Hours DESC
    ) AS Delay_Rank
FROM Shipments;

-- 4.Identify the average delay per Delivery_Type (Express / Standard) to compare service-level efficiency.
SELECT
    o.Delivery_Type,
    ROUND(AVG(s.Delay_Hours), 2) AS Avg_Delay_Hours
FROM Orders o
JOIN Shipments s
    ON o.Order_ID = s.Order_ID
GROUP BY o.Delivery_Type
ORDER BY Avg_Delay_Hours;

-- Task 3: Route Optimization Insights
-- 1.Average transit time (in hours) across all shipments.
SELECT
    Route_ID,
    ROUND(
        AVG(EXTRACT(EPOCH FROM (Delivery_Date - Pickup_Date)) / 3600),
        2
    ) AS Avg_Transit_Time_Hours
FROM Shipments
GROUP BY Route_ID
ORDER BY Avg_Transit_Time_Hours DESC;

-- 2.Average delay (in hours) per route.
SELECT
    r.Route_ID,
    r.Source_City,
    r.Destination_City,
    ROUND(AVG(s.Delay_Hours), 2) AS Avg_Delay_Hours
FROM Shipments s
JOIN Routes r
    ON s.Route_ID = r.Route_ID
GROUP BY
    r.Route_ID,
    r.Source_City,
    r.Destination_City
ORDER BY Avg_Delay_Hours DESC;

-- 3.Distance-to-time efficiency ratio = Distance_KM / Avg_Transit_Time_Hours.
SELECT
    Route_ID,
    Source_City,
    Destination_City,
    Distance_KM,
    Avg_Transit_Time_Hours,
    ROUND(
        Distance_KM / Avg_Transit_Time_Hours,
        2
    ) AS Efficiency_Ratio
FROM Routes
ORDER BY Efficiency_Ratio DESC;

-- 4.Identify 3 routes with the worst efficiency ratio (lowest distance-to-time).
SELECT
    Route_ID,
    Source_City,
    Destination_City,
    Distance_KM,
    Avg_Transit_Time_Hours,
    ROUND(
        Distance_KM / Avg_Transit_Time_Hours,
        2
    ) AS Efficiency_Ratio
FROM Routes
ORDER BY Efficiency_Ratio ASC
LIMIT 3;

-- 5.Find routes with >20% of shipments delayed beyond expected transit time.
SELECT
    Route_ID,
    COUNT(*) AS Total_Shipments,
    COUNT(*) FILTER (
        WHERE Delivery_Date > Expected_Delivery_Date
    ) AS Delayed_Shipments,
    ROUND(
        COUNT(*) FILTER (
            WHERE Delivery_Date > Expected_Delivery_Date
        ) * 100.0 / COUNT(*),
        2
    ) AS Delay_Percentage
FROM Shipments
GROUP BY Route_ID
HAVING (
    COUNT(*) FILTER (
        WHERE Delivery_Date > Expected_Delivery_Date
    ) * 100.0 / COUNT(*)
) > 20
ORDER BY Delay_Percentage DESC;
/*Routes where more than 20% of shipments exceeded their expected delivery times were identified.
These routes represent high-risk transportation corridorsand may require process improvements,
route redesign, or additional resources to improve service reliability. */

-- 6.Recommend potential routes or hub pairs for optimization.
SELECT
    r.Route_ID,
    r.Source_City,
    r.Destination_City,
    ROUND(AVG(s.Delay_Hours), 2) AS Avg_Delay_Hours,
    ROUND(r.Distance_KM / r.Avg_Transit_Time_Hours, 2) AS Efficiency_Ratio,
    ROUND(
        COUNT(*) FILTER (
            WHERE s.Delivery_Date > s.Expected_Delivery_Date
        ) * 100.0 / COUNT(*),
        2
    ) AS Delay_Percentage
FROM Routes r
JOIN Shipments s
    ON r.Route_ID = s.Route_ID
GROUP BY
    r.Route_ID,
    r.Source_City,
    r.Destination_City,
    r.Distance_KM,
    r.Avg_Transit_Time_Hours
ORDER BY
    Avg_Delay_Hours DESC,
    Efficiency_Ratio ASC;

-- Task 4: Warehouse Performance
-- 1.Find the top 3 warehouses with the highest average delay in shipments dispatched.
SELECT
    w.Warehouse_ID,
    w.City,
    w.Country,
    ROUND(AVG(s.Delay_Hours), 2) AS Avg_Delay_Hours
FROM Shipments s
JOIN Warehouses w
    ON s.Warehouse_ID = w.Warehouse_ID
GROUP BY
    w.Warehouse_ID,
    w.City,
    w.Country
ORDER BY Avg_Delay_Hours DESC
LIMIT 3;

-- 2.Calculate total shipments vs delayed shipments for each warehouse.
SELECT
    w.Warehouse_ID,
    w.City,
    w.Country,
    COUNT(s.Shipment_ID) AS Total_Shipments,
    COUNT(*) FILTER (
        WHERE s.Delivery_Date > s.Expected_Delivery_Date
    ) AS Delayed_Shipments
FROM Warehouses w
JOIN Shipments s
    ON w.Warehouse_ID = s.Warehouse_ID
GROUP BY
    w.Warehouse_ID,
    w.City,
    w.Country
ORDER BY Delayed_Shipments DESC;

-- 3.Use CTEs to identify warehouses where average delay exceeds the global average delay.
WITH Global_Average AS (
    SELECT AVG(Delay_Hours) AS Global_Avg_Delay
    FROM Shipments
),
Warehouse_Average AS (
    SELECT
        w.Warehouse_ID,
        w.City,
        w.Country,
        ROUND(AVG(s.Delay_Hours), 2) AS Warehouse_Avg_Delay
    FROM Shipments s
    JOIN Warehouses w
        ON s.Warehouse_ID = w.Warehouse_ID
    GROUP BY
        w.Warehouse_ID,
        w.City,
        w.Country
)

SELECT
    wa.Warehouse_ID,
    wa.City,
    wa.Country,
    wa.Warehouse_Avg_Delay,
    ROUND(ga.Global_Avg_Delay, 2) AS Global_Avg_Delay
FROM Warehouse_Average wa
CROSS JOIN Global_Average ga
WHERE wa.Warehouse_Avg_Delay > ga.Global_Avg_Delay
ORDER BY wa.Warehouse_Avg_Delay DESC;

-- 4.Rank all warehouses based on on-time delivery percentage.
SELECT
    w.Warehouse_ID,
    w.City,
    w.Country,
    COUNT(*) AS Total_Shipments,
    COUNT(*) FILTER (
        WHERE s.Delivery_Date <= s.Expected_Delivery_Date
    ) AS On_Time_Shipments,
    ROUND(
        COUNT(*) FILTER (
            WHERE s.Delivery_Date <= s.Expected_Delivery_Date
        ) * 100.0 / COUNT(*),
        2
    ) AS On_Time_Percentage,
    RANK() OVER (
        ORDER BY
        ROUND(
            COUNT(*) FILTER (
                WHERE s.Delivery_Date <= s.Expected_Delivery_Date
            ) * 100.0 / COUNT(*),
            2
        ) DESC
    ) AS Warehouse_Rank
FROM Shipments s
JOIN Warehouses w
    ON s.Warehouse_ID = w.Warehouse_ID
GROUP BY
    w.Warehouse_ID,
    w.City,
    w.Country
ORDER BY Warehouse_Rank;

-- Task 5: Delivery Agent Performance
-- 1.Rank delivery agents (per route) by on-time delivery percentage.
WITH Agent_Performance AS (
    SELECT
        s.Route_ID,
        s.Agent_ID,
        a.Agent_Name,
        COUNT(*) AS Total_Shipments,
        COUNT(*) FILTER (
            WHERE s.Delivery_Date <= s.Expected_Delivery_Date
        ) AS On_Time_Shipments,
        ROUND(
            COUNT(*) FILTER (
                WHERE s.Delivery_Date <= s.Expected_Delivery_Date
            ) * 100.0 / COUNT(*),
            2
        ) AS On_Time_Percentage
    FROM Shipments s
    JOIN Delivery_Agents a
        ON s.Agent_ID = a.Agent_ID
    GROUP BY
        s.Route_ID,
        s.Agent_ID,
        a.Agent_Name
)

SELECT
    Route_ID,
    Agent_ID,
    Agent_Name,
    Total_Shipments,
    On_Time_Shipments,
    On_Time_Percentage,
    RANK() OVER (
        PARTITION BY Route_ID
        ORDER BY On_Time_Percentage DESC
    ) AS Agent_Rank
FROM Agent_Performance
ORDER BY Route_ID, Agent_Rank;

-- 2.Find agents whose on-time % is below 85%.
WITH Agent_Performance AS (
    SELECT
        a.Agent_ID,
        a.Agent_Name,
        COUNT(*) AS Total_Shipments,
        COUNT(*) FILTER (
            WHERE s.Delivery_Date <= s.Expected_Delivery_Date
        ) AS On_Time_Shipments,
        ROUND(
            COUNT(*) FILTER (
                WHERE s.Delivery_Date <= s.Expected_Delivery_Date
            ) * 100.0 / COUNT(*),
            2
        ) AS On_Time_Percentage
    FROM Shipments s
    JOIN Delivery_Agents a
        ON s.Agent_ID = a.Agent_ID
    GROUP BY
        a.Agent_ID,
        a.Agent_Name
)

SELECT *
FROM Agent_Performance
WHERE On_Time_Percentage < 85
ORDER BY On_Time_Percentage;

-- 3.Compare the average rating and experience (in years) of the top 5 vs bottom 5 agents using subqueries.
SELECT
    'Top 5 Agents' AS Agent_Group,
    ROUND(AVG(Avg_Rating), 2) AS Avg_Rating,
    ROUND(AVG(Experience_Years), 2) AS Avg_Experience_Years
FROM (
    SELECT Avg_Rating, Experience_Years
    FROM Delivery_Agents
    ORDER BY Avg_Rating DESC
    LIMIT 5
) Top_Agents

UNION ALL

SELECT
    'Bottom 5 Agents' AS Agent_Group,
    ROUND(AVG(Avg_Rating), 2) AS Avg_Rating,
    ROUND(AVG(Experience_Years), 2) AS Avg_Experience_Years
FROM (
    SELECT Avg_Rating, Experience_Years
    FROM Delivery_Agents
    ORDER BY Avg_Rating ASC
    LIMIT 5
) Bottom_Agents;

-- 4.Suggest training or workload balancing strategies for low-performing agents based on insights.
/*
Based on the analysis, DHL should implement targeted training and workload balancing strategies for low-performing agents.
Agents with low on-time delivery percentages or customer ratings should receive additional training in route planning,
time management, and customer service. A mentorship program can be introduced where experienced agents guide
lower-performing agents to improve operational efficiency.
Workload should also be distributed more evenly to prevent excessive shipment assignments that may lead to delays.
Complex or high-volume routes can be assigned to more experienced agents, while newer agents can handle simpler
routes until their performance improves.
Regular monitoring of key performance indicators such as on-time delivery percentage, average delay hours,
and customer ratings will help identify agents requiring support. Additionally, recognizing and rewarding
high-performing agents can motivate the workforce and improve overall delivery performance and customer satisfaction.
*/

-- Task 6: Shipment Tracking Analytics
-- 1.For each shipment, display the latest status (Delivered, In Transit, or Returned) along with the latest Delivery_Date.
WITH Latest_Shipment_Status AS (
    SELECT
        Shipment_ID,
        Delivery_Status,
        Delivery_Date,
        ROW_NUMBER() OVER (
            PARTITION BY Shipment_ID
            ORDER BY Delivery_Date DESC
        ) AS rn
    FROM Shipments
)

SELECT
    Shipment_ID,
    Delivery_Status,
    Delivery_Date
FROM Latest_Shipment_Status
WHERE rn = 1;

-- 2.Identify routes where the majority of shipments are still “In Transit” or “Returned”.
SELECT
    Route_ID,
    COUNT(*) AS Total_Shipments,
    COUNT(*) FILTER (
        WHERE Delivery_Status IN ('In Transit', 'Returned')
    ) AS Pending_or_Returned_Shipments,
    ROUND(
        COUNT(*) FILTER (
            WHERE Delivery_Status IN ('In Transit', 'Returned')
        ) * 100.0 / COUNT(*),
        2
    ) AS Percentage
FROM Shipments
GROUP BY Route_ID
ORDER BY Percentage DESC;

-- 3.Find the most frequent delay reasons (if available in delay-related columns or flags).
SELECT
    Delay_Reason,
    COUNT(*) AS Frequency
FROM Shipments
WHERE Delay_Reason <> 'No Delay'
GROUP BY Delay_Reason
ORDER BY Frequency DESC;

-- 4.Identify orders with exceptionally high delay (>120 hours) to investigate potential bottlenecks.
SELECT
    o.Order_ID,
    s.Shipment_ID,
    o.Customer_ID,
    o.Delivery_Type,
    s.Route_ID,
    s.Warehouse_ID,
    s.Delay_Hours,
    s.Delay_Reason
FROM Orders o
JOIN Shipments s
    ON o.Order_ID = s.Order_ID
WHERE s.Delay_Hours > 120
ORDER BY s.Delay_Hours DESC;

-- Task 7: Advanced KPI Reporting
-- 1.Average Delivery Delay per Source_Country.
SELECT
    r.Source_Country,
    ROUND(AVG(s.Delay_Hours), 2) AS Avg_Delivery_Delay_Hours
FROM Shipments s
JOIN Routes r
    ON s.Route_ID = r.Route_ID
GROUP BY r.Source_Country
ORDER BY Avg_Delivery_Delay_Hours DESC;

-- 2.On-Time Delivery % = (Total On-Time Deliveries / Total Deliveries) * 100.
SELECT
    COUNT(*) AS Total_Deliveries,
    COUNT(*) FILTER (
        WHERE Delivery_Date <= Expected_Delivery_Date
    ) AS On_Time_Deliveries,
    ROUND(
        COUNT(*) FILTER (
            WHERE Delivery_Date <= Expected_Delivery_Date
        ) * 100.0 / COUNT(*),
        2
    ) AS On_Time_Delivery_Percentage
FROM Shipments;

-- 3.Average Delay (in hours) per Route_ID.
SELECT
    r.Route_ID,
    r.Source_City,
    r.Destination_City,
    ROUND(AVG(s.Delay_Hours), 2) AS Avg_Delay_Hours
FROM Shipments s
JOIN Routes r
    ON s.Route_ID = r.Route_ID
GROUP BY
    r.Route_ID,
    r.Source_City,
    r.Destination_City
ORDER BY Avg_Delay_Hours DESC;

-- 4.Warehouse Utilization % = (Shipments_Handled / Capacity_per_day) * 100.
SELECT
    w.Warehouse_ID,
    w.City,
    w.Country,
    w.Capacity_per_day,
    COUNT(s.Shipment_ID) AS Shipments_Handled,
    ROUND(
        COUNT(s.Shipment_ID) * 100.0 / w.Capacity_per_day,
        2
    ) AS Warehouse_Utilization_Percentage
FROM Warehouses w
JOIN Shipments s
    ON w.Warehouse_ID = s.Warehouse_ID
GROUP BY
    w.Warehouse_ID,
    w.City,
    w.Country,
    w.Capacity_per_day
ORDER BY Warehouse_Utilization_Percentage DESC;



-- Separate KPI Summary Table
SELECT
    COUNT(*) AS Total_Deliveries,

    SUM(
        CASE
            WHEN Delivery_Date <= Expected_Delivery_Date
            THEN 1
            ELSE 0
        END
    ) AS On_Time_Deliveries,

    ROUND(
        SUM(
            CASE
                WHEN Delivery_Date <= Expected_Delivery_Date
                THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS On_Time_Delivery_Percentage,

    ROUND(AVG(Delay_Hours), 2) AS Average_Delay_Hours,

    SUM(
        CASE
            WHEN Delay_Hours > 0
            THEN 1
            ELSE 0
        END
    ) AS Delayed_Shipments
FROM Shipments;

/* Aggregate functions and CASE statements were used to create KPI summary tables for DHL's logistics network.
These KPIs provide a consolidated view of delivery reliability, delay patterns, and operational efficiency,
enabling data-driven decision-making and performance monitoring. */




