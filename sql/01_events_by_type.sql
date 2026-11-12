SELECT data ->> 'event_type' AS event_type, COUNT(*)
FROM raw.events
GROUP BY data ->> 'event_type';
