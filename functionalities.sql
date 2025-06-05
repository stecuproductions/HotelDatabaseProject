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

-- 4. Service Management
-- • Add and update additional services
INSERT INTO services (service_name, service_price) VALUES ('Laundry Service', 60.00);
INSERT INTO services (service_name, service_price) VALUES ('Pet Fee', 70.00);

DECLARE
    v_service_id_to_update NUMBER;
BEGIN
    SELECT id_service INTO v_service_id_to_update
    FROM services
    WHERE service_name = 'Pet Fee';

    update_service(
        p_id_service        => v_service_id_to_update,
        p_new_service_name  => 'Extended Pet Stay Fee',
        p_new_service_price => 75.00
    );
    
    DBMS_OUTPUT.PUT_LINE('Service with ID: ' || v_service_id_to_update || ' has been updated.');
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Service with name "Pet Fee" not found.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('An error occurred while updating the service: ' || SQLERRM);
END;
/

-- • The services can be assigned to the reservation
-- ??? nwm czy chodzi o to ze jest procedura czy co

-- 5. Reservation Services Management
-- • Identifiers are used to calculated total price of the reservation
-- Example of calling calculate_total_price function
DECLARE
    v_total_calculated_price NUMBER;
    v_service_ids service_id_table := service_id_table(1, 3); 
    v_room_id NUMBER := 1;
    v_start_date DATE := DATE '2025-08-01';
    v_end_date DATE := DATE '2025-08-03';
BEGIN
    v_total_calculated_price := calculate_total_price(
        p_id_services => v_service_ids,
        p_id_room     => v_room_id,
        p_start_date  => v_start_date,
        p_end_date    => v_end_date
    );

    DBMS_OUTPUT.PUT_LINE('Calculated Total Reservation Price: ' || v_total_calculated_price);
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        RAISE;
END;
/

-- • Ability to extend each reservation with additional services
-- Przykład użycia procedury add_services_to_existing_reservation
DECLARE
    v_existing_reservation_id NUMBER := 1;
    v_services_to_add service_id_table := service_id_table(2, 4);
BEGIN
    add_services_to_existing_reservation(
        p_id_reservation  => v_existing_reservation_id,
        p_new_service_ids => v_services_to_add
    );
END;
/
