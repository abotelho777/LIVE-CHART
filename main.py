import numpy as np
import datautility as du
from time import sleep
# from flask import Flask, request, session, g, redirect, \
#      render_template
import os

SQL_FOLDER = 'resources/SQL/'
# app = Flask(__name__)
app_args = du.read_paired_data_file(os.path.dirname(os.path.abspath(__file__))+'\config.txt')
# app.secret_key = app_args['secret_key']
db = None


def connect_db():
    db = du.db_connect(app_args['db_name'], app_args['username'], app_args['password'],
                       host=app_args['host'], port=app_args['port'])
    return db


def time_to_seconds(db, time):
    _vars, _query = du.read_var_text_file(SQL_FOLDER + 'time_to_seconds_from_midnight.sql', sep=' ')
    _vars[':time'] = str(time)
    return du.db_query(db, _query, _vars)[0][0]


def seconds_to_time(db, time, date):
    _vars, _query = du.read_var_text_file(SQL_FOLDER + 'seconds_from_midnight_to_time.sql', sep=' ')
    _vars[':seconds_from_midnight'] = time
    _vars[':date'] = str(date)
    return str(du.db_query(db, _query, _vars)[0][0])


def earliest_action_time(db, date, class_section):
    _vars, _query = du.read_var_text_file(SQL_FOLDER + 'earliest_action_time.sql', sep=' ')
    _vars[':student_class_section_id'] = str(class_section)
    _vars[':date'] = date
    return str(du.db_query(db, _query, _vars)[0][0])


def get_all_actions(db, date, class_section):
    _vars, _query = du.read_var_text_file(SQL_FOLDER + 'get_all_actions.sql', sep=' ')
    _vars[':student_class_section_id'] = str(class_section)
    _vars[':date'] = date
    res, headers = du.db_query(db, _query, _vars, return_column_names=True)
    return {'headers': np.array(headers), 'data': np.array(res)}


def get_recent_actions(db, date, class_section, time, offset=1, source=None):
    if source is None:
        _vars, _query = du.read_var_text_file(SQL_FOLDER + 'recent_actions.sql', sep='\n')
        _vars[':seconds_from_midnight'] = time
        _vars[':student_class_section_id'] = str(class_section)
        _vars[':date'] = str(date)
        _vars[':time_offset'] = offset
        return du.db_query(db, _query, _vars, return_column_names=True)
    else:
        if source is not dict and (not len(source['data'].shape) == 2 or not source['data'].shape[-1] == 18):
            raise ValueError('Source must be the result of a get_all_actions call or None')
        return source['data'][np.argwhere([time-offset < i <= time for i in source['data'][:, -1]]).ravel(), :-1],\
               source['headers']


if __name__ == '__main__':
    db = connect_db()

    date = '2018-06-08 8:30:00'
    class_section = 96680
    time = earliest_action_time(db, date, class_section)
    time_s = time_to_seconds(db, date)  # time_to_seconds(db,time)

    action_history = get_all_actions(db, date, class_section)

    increment = 1
    speed = 30
    while True:
        res, headers = get_recent_actions(db, date, class_section, time_s, increment, source=action_history)
        for i in res:
            msg = 'user {} :: {}'.format(i[3],i[8])
            print('{}: {}'.format(str(i[16]), msg))
        time_s += increment
        sleep(increment / speed)
