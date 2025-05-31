--Prevent_double_booking 
--It throws an exception when the administrator is trying to book already booked room. 
CREATE OR REPLACE TRIGGER prevent_double_booking
BEFORE INSERT OR UPDATE ON reservations
FOR EACH ROW
DECLARE
    v_conflict_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_conflict_count
    FROM reservations
    WHERE id_room = :NEW.id_room
      AND status IN ('Awaiting', 'Active')
      AND (
            :NEW.start_date <= end_date
        AND :NEW.end_date >= start_date
      )
      AND (:NEW.id_reservation IS NULL OR id_reservation != :NEW.id_reservation);

    IF v_conflict_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Double booking not allowed: the room is already booked in the given date range.');
    END IF;
END;
/

-- free_room_on_cancellation 
-- It sets room status to  ‘free’  when the book is CURRENTLY occupied and the reservation is cancelled. 
CREATE OR REPLACE TRIGGER free_room_on_cancellation
AFTER UPDATE ON reservations
FOR EACH ROW
WHEN (
    OLD.status = 'Active' AND NEW.status = 'Cancelled'
)
BEGIN
    UPDATE rooms
    SET is_available = 'Y'
    WHERE id_room = :NEW.id_room;
END;
/

-- validate_reservation_dates 
-- It prevents from inserting a reservation with date earlier than todays date. 
CREATE OR REPLACE TRIGGER validate_reservation_dates
BEFORE INSERT OR UPDATE ON reservations
FOR EACH ROW
BEGIN
    IF :NEW.start_date < TRUNC(SYSDATE) OR :NEW.end_date < TRUNC(SYSDATE) THEN
        RAISE_APPLICATION_ERROR(-20004, 'Reservation dates cannot be in the past.');
    END IF;
END;
/
