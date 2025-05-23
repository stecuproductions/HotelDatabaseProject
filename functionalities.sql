-- 1. Guest Management 
-- • Add guests with basic personal and contact details 
INSERT INTO guests (first_name, last_name, phone, email) VALUES ('Anna', 'Nowak', '987654321', 'anna@gmail.com');
-- • View a list of currently registered guests 
SELECT * FROM guests;
-- • Edit or update information about guests 
UPDATE guests SET phone = '987654321' WHERE id_guest = 1;
-- • Delete guests – only when they stay is over
DELETE FROM guests WHERE id_guest = 1 AND id_guest NOT IN (SELECT id_guest FROM reservations WHERE status = 'Active');


-- 2. Room Management 
-- • Add new room 
INSERT INTO rooms (room_number, room_type, price_per_night) VALUES ('101', 'double', 150.00);
-- • View a list of all rooms the hotel has 
SELECT * FROM rooms;
-- • Storing information about a room 
SELECT * FROM rooms WHERE room_number = '101';
-- • Update the room’s price per night  
    update_room_price(2, 150.00); 
-- • Automatic change of the room’s status to “free” after the annulment of 
-- active reservation 
-- free_room_on_cancellation trigger used
-- • Prevention of double booking a room that is already booked 
-- prevent_double_booking trigger used
-- • Automatic change of availability of the room
-- DBMS scheduler used


--3. Reservation Management

-- • Adding a reservation which checks the availability of the room, calculates 
-- the cost of the reservation and handles exceptions (when there are no 
-- rooms available for example)
see_free_rooms_on_date(
        TO_DATE('2026-06-01', 'YYYY-MM-DD'),
        TO_DATE('2028-06-05', 'YYYY-MM-DD'),
        'double'
    );
DECLARE
    v_service_ids service_id_table := service_id_table(1, 2, 3);
BEGIN
    add_reservation_with_services(1, 1, DATE '2025-07-01', DATE '2025-08-05', v_service_ids);
END;
/

-- • Anulment of the reservation
UPDATE reservations SET status = 'Cancelled' WHERE id_reservation = 1;

-- •  Validation of the dates of the reservation (to check that the dates are not from the past)
 --validate_reservation_dates trigger used

-- • Storing the data of the reservations
SELECT * FROM reservations;
--OR 
SELECT r.id_reservation, r.start_date, r.end_date, r.total_price, g.first_name, g.last_name
FROM reservations r
JOIN guests g ON r.id_guest = g.id_guest
WHERE r.status = 'Active';
--OR
SELECT r.id_reservation, r.start_date, r.end_date, r.total_price FROM reservations r
JOIN guests g ON r.id_guest = g.id_guest
WHERE g.first_name = 'John' AND g.last_name = 'Doe';

