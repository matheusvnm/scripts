from datetime import datetime
from speedtest import Speedtest
import pandas as pd
import warnings
import time 
import os

def capture_internet_speed(filename, should_shutdown_machine, time_limit, interval):
    executed_time = 0
    start_hour = datetime.now().hour
    while executed_time < time_limit:
        new_line_data = capture_speed_now()
        save_row_in_excel(filename, new_line_data)
        time.sleep(interval)
        executed_time = get_executed_time(start_hour)
    if should_shutdown_machine:
        os.system("shutdown /s /t 1") 

def capture_speed_now():
    sp = Speedtest()
    date_time = datetime.now().strftime('%d/%m/%Y %H:%M')
    download = sp.download(threads=None)*(10**-6)
    upload = sp.upload(threads=None)*(10**-6)
    print_data(date_time, download, upload)
    return {'Horário': date_time, 'Download': download, 'Upload': upload}
   

def print_data(date_time, download, upload):
    print(f"[{date_time}]")
    print(f"Download: {download}")
    print(f"Upload: {upload}\n")

def save_row_in_excel(filename, new_line_data):
    exists = os.path.isfile(filename)
    if not exists:
        create_dataframe_file(filename)
    dataframe = read_excel_as_dataframe(filename)
    next_line = verify_last_index(dataframe)+1
    dataframe.loc[next_line] = new_line_data 
    save_dataframe_as_excel(filename, dataframe)

def create_dataframe_file(filename):
    dataframe_columns = ['Horário', 'Download', 'Upload']
    dataframe = pd.DataFrame(columns = dataframe_columns) 
    save_dataframe_as_excel(filename, dataframe)

def read_excel_as_dataframe(filename):
    return pd.read_excel(filename, sheet_name='speed')

def verify_last_index(dataframe):
    if dataframe.empty:
        return 0
    else:
        return dataframe.last_valid_index()

def save_dataframe_as_excel(filename, dataframe):
    dataframe.to_excel(filename, sheet_name='speed', index=False)

def get_executed_time(start_hour):
    return datetime.now().hour - start_hour


warnings.filterwarnings("ignore")
capture_internet_speed(
    filename = "speed_data.xls", should_shutdown_machine = False, 
    time_limit = 5, interval = 60)
