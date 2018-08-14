-- gets the timestamp of the first action made by students in :student_class_section on :date,
SELECT actions.action_time FROM (
SELECT actions.ordering, actions.problem_log_id, actions.assignment_id, actions.user_id, actions.original, actions.problem_correctness,
actions.start_time, actions.end_time, actions.action_name, actions.correct, actions.answer_text, actions.work_span, actions.offset_start, actions.offset_last, actions.offset_last/1000. AS offset_seconds,
actions.milli_time, actions.action_time FROM (
SELECT *, sum(offset_last) OVER (PARTITION BY work_span ORDER BY ordering) AS milli_time,
CASE
WHEN action_name='start' THEN start_time
WHEN action_name='resume' THEN (timestamp with time zone 'epoch' + (offset_start * interval '1 millisecond'))::timestamp without time zone
ELSE (timestamp with time zone 'epoch' + ((start_milli + sum(offset_last) OVER (PARTITION BY problem_log_id ORDER BY ordering)) * interval '1 millisecond'))::timestamp without time zone
END AS action_time

FROM (
WITH sa AS (
SELECT row_number() OVER (PARTITION BY problem_log_id ORDER BY action_index) AS ordering, problem_log_id, assignment_id, user_id,original, problem_correctness,start_time, end_time, action_ar, action_name,
CASE WHEN action_name = 'end' THEN 1 ELSE milli_offset END AS milli_offset, correct, answer_text FROM (
SELECT action_index, problem_log_id, assignment_id, user_id, start_time, end_time,original, problem_correctness, string_to_array(ac,'\n') AS action_ar,
(string_to_array(replace(ac,' ','\n'),'\n'))[1] AS action_name,
NULLIF((string_to_array(replace(ac,' ','\n'),'\n'))[2], '')::double precision AS milli_offset,
CASE WHEN (string_to_array(replace(ac,' ','\n'),'\n'))[1] = 'answer'
THEN ((string_to_array(replace(ac,' ','\n'),'\n'))[3] = 'true')::INT
ELSE NULL
END AS correct,
CASE WHEN (string_to_array(replace(ac,' ','\n'),'\n'))[1] = 'answer'
THEN (string_to_array(replace(ac,' ','\n'),'\n'))[4]
ELSE NULL
END AS answer_text
FROM (
SELECT * FROM (
SELECT id AS problem_log_id,assignment_id,user_id,start_time,end_time,original, correct AS problem_correctness, y.elem AS ac, y.action_index FROM (
-------------------- PROBLEM LOGS TO GENERATE FEATURES
--SELECT id, actions FROM problem_logs LIMIT 10000
SELECT * FROM problem_logs WHERE (user_id, assignment_id) IN (

WITH student_user_classes AS (
SELECT * FROM (
	SELECT student_id, student_class_id FROM enrollments
	WHERE student_class_section_id = :student_class_section_id
) AS sc
LEFT OUTER JOIN user_roles ur ON ur.id = sc.student_id
)

SELECT user_id, assignment_id FROM assignment_logs
WHERE user_id IN (SELECT user_id FROM student_user_classes)
AND assignment_id IN (SELECT id FROM class_assignments
	WHERE student_class_id IN (SELECT student_class_id FROM student_user_classes
	))
AND CASE WHEN end_time IS NOT NULL THEN start_time <= date_trunc('day',timestamp :date) AND end_time > date_trunc('day',timestamp :date)
ELSE start_time <= date_trunc('day',timestamp :date) AND last_worked_on > date_trunc('day',timestamp :date) END)

--------------------
) AS plog
LEFT JOIN LATERAL unnest(string_to_array(id::TEXT || '_actionstart' ||
replace(replace(regexp_replace(replace(replace(actions,'~','<tilda>'),'\n- -','~'),'[^a-zA-Z0-9\n~]', '', 'g'), '\n\n', '\n'),'\n',' ')
|| '~' || id::TEXT || '_actionend','~')) WITH ORDINALITY AS y(elem, action_index) ON TRUE

) AS a_str
) AS actionlevel
) AS action_table
WHERE position('action' IN action_name) = 0
)
SELECT sa.ordering, sa.problem_log_id,sa.assignment_id, sa.user_id,sa.original,sa.problem_correctness,sa.start_time, sa.end_time, sa.action_ar, sa.action_name, sa.correct, sa.answer_text,
sum((sa.action_name = 'start' OR sa.action_name = 'resume')::INT) OVER (ORDER BY sa.problem_log_id, sa.ordering) AS work_span,
CASE WHEN sa.action_name = 'end' AND at.action_name != 'resume' THEN at.milli_offset + 1 ELSE sa.milli_offset END AS offset_start,
CASE
WHEN sa.action_name = 'start' THEN 0
WHEN sa.action_name = 'resume' AND at.action_name = 'resume' THEN sa.milli_offset-at.milli_offset
WHEN sa.action_name = 'resume' AND at.action_name = 'start' THEN sa.milli_offset-st.milli_offset
WHEN sa.action_name = 'resume' THEN (sa.milli_offset-st.milli_offset)-at.milli_offset
WHEN at.action_name = 'resume' THEN sa.milli_offset-(at.milli_offset-st.milli_offset)
ELSE sa.milli_offset-(at.milli_offset*((1-(at.action_name = 'start' OR sa.action_name = 'end')::INT)::DOUBLE PRECISION)) END AS offset_last, st.milli_offset AS start_milli
FROM sa
LEFT OUTER JOIN sa at ON at.problem_log_id = sa.problem_log_id AND at.ordering = sa.ordering-1
LEFT OUTER JOIN (SELECT problem_log_id, milli_offset FROM sa WHERE ordering = 1) AS st ON st.problem_log_id = sa.problem_log_id
) AS working
) AS actions

UNION

SELECT 1 AS ordering, NULL AS problem_log_id, NULL AS assignment_id, user_id, NULL AS original, NULL AS problem_correctness, start AS start_time, finish AS end_time,
action AS action_name, NULL AS correct, NULL AS answer_text, NULL AS work_span, NULL AS offset_start, NULL AS offset_last, NULL AS offset_seconds,
NULL AS milli_time, start AS action_time FROM (
SELECT * FROM logged_actions WHERE action = 'login' AND
start > date_trunc('day',timestamp :date )
AND start < date_trunc('day',timestamp :date ) + interval '1 day'
) AS la WHERE la.user_id != 433034

) AS actions
WHERE date_trunc('day',action_time) = date_trunc('day',timestamp :date )
ORDER BY action_time
LIMIT 1