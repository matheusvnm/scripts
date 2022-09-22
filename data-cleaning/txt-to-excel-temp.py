from openpyxl import load_workbook
import pandas as pd
import numpy as np
from os import listdir, chdir, getcwd
from os.path import isfile, join, exists


class File:
    def __init__(self, config_name, iteration):
        self.config_name = config_name
        self.iteration = iteration


def clean_file(filename: str):
    splitted_filename = filename.split(".")
    splitted_filename.remove('txt')
    return splitted_filename


def read_columns(filename):
    file = open(filename, "r")
    column = [line.rstrip() for line in file]
    column = [word.replace(".", ",") for word in column]
    return column


def create_table(config, columns, directory):
    filename = f"TBTF_Temp_{directory}.xlsx"
    df = pd.DataFrame(dict([(k, pd.Series(v)) for k, v in columns.items()]))
    cols_to_sort = list(df.columns)
    cols_to_sort.sort()
    if not exists(filename):
        df[cols_to_sort].to_excel(filename, sheet_name=config)
        return
    writer = pd.ExcelWriter(filename, engine='openpyxl', mode='a')
    writer.book = load_workbook(filename)
    writer.sheets = {ws.title: ws for ws in writer.book.worksheets}
    df[cols_to_sort].to_excel(writer, sheet_name=config)
    writer.save()


def main():
    main_dir = getcwd()
    directories = ["Ibicui"]
    for directory in directories:
        chdir(directory+"/Temp"+"/Clean")
        files_fullname = [file for file in listdir(".") if isfile(
            join(".", file)) and file.endswith(".txt")]
        files_fullname.sort()
        processed_files = list()
        for filename in files_fullname:
            splitted_filename = clean_file(filename)
            if filename not in processed_files:
                processed_files.append(filename)
                config = "_".join(
                    i for i in splitted_filename if not i.isdigit() or int(i) > 20)
                file = File(
                    config, splitted_filename[len(splitted_filename)-1])
                columns = dict()
                columns[file.iteration] = np.array(read_columns(filename))

                for next_filename in files_fullname:
                    splitted_filename = clean_file(next_filename)
                    config = "_".join(
                        i for i in splitted_filename if not i.isdigit() or int(i) > 20)
                    next_file = File(
                        config, splitted_filename[len(splitted_filename)-1])

                    if file.config_name == next_file.config_name and not file.iteration == next_file.iteration:
                        processed_files.append(next_filename)
                        columns[next_file.iteration] = np.array(
                            read_columns(next_filename))
                create_table(file.config_name, columns, directory)
            chdir(main_dir)


if __name__ == '__main__':
    main()