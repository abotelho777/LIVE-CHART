-- gets :time as seconds from midnight
SELECT (extract(epoch FROM (:time)::timestamp without time zone))-(extract(epoch FROM date_trunc('day', (:time)::timestamp without time zone)))