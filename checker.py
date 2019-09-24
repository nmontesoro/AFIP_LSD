import sys


class field():
    length = 0
    name = ""
    type = ""


def parse_file(file_pointer):
    arr_fields = []
    line_split_result = []

    for line in file_pointer.readlines():
        if line[0] != '*':  # Ignoro comentarios
            line_split_result = line.split('|', maxsplit=4)

            tmp_field_object = field()

            tmp_field_object.type = line_split_result[0]
            tmp_field_object.name = line_split_result[1]
            tmp_field_object.length = int(line_split_result[2])

            arr_fields.append(tmp_field_object)

    return arr_fields


def close_files(arr_file_pointers):
    for file_pointer in arr_file_pointers:
        file_pointer.close()


def parse_line(arr_fields, line):
    parsed_line = ""
    tmp_parsed_line = ""
    start_index = 0

    for field in arr_fields:
        tmp_parsed_line = line[start_index:field.length + start_index]

        if field.type.lower() == "n":
            # Agrego punto decimal
            tmp_parsed_line = tmp_parsed_line[:-2] + "," + tmp_parsed_line[-2:]

        parsed_line += tmp_parsed_line + ";"
        start_index += field.length

    return parsed_line


def get_header(arr_field):
    header = ""

    for field in arr_field:
        header += field.name + ";"

    return header


if len(sys.argv) != 2:
    print("Cantidad errónea de argumentos.")
    print("\nUSO: checker.py archivo_a_comprobar.txt")
    exit(3)

# Abro los archivos de configuración
arr_file_pointers = []
for i in range(1, 5):
    try:
        arr_file_pointers.append(open("LSD/%02i.txt" % (i), "rt",
                                      encoding="cp1252"))
    except:
        print("ERROR: Error al leer el archivo LSD/%02i.txt" % (i))
        close_files(arr_file_pointers)
        exit(4)

# Parseo
arr_fields_by_id_no = []
for file_pointer in arr_file_pointers:
    arr_fields_by_id_no.append(parse_file(file_pointer))

# Ya no necesito tener abiertos los archivos
close_files(arr_file_pointers)

# Abro el archivo de AFIP
try:
    file = open(sys.argv[1], "rt")
except:
    print("ERROR: Error al leer el archivo de entrada %s" % (sys.argv[1]))
    exit(5)

# Abro los archivos de salida, y escribo el header de cada uno
arr_file_pointers = []
for i in range(1, 5):
    try:
        arr_file_pointers.append(open("LSD/registros_%02i.csv" % (i), "wt"))
        print(get_header(arr_fields_by_id_no[i - 1]),
              file=arr_file_pointers[i - 1])
    except:
        print("ERROR: No se puede escribir al archivo LSD/registros_%02i.csv"
              % (i))
        close_files(arr_file_pointers)
        exit(6)

for line in file.readlines():
    id_registro = int(line[:2])
    tmp_line = parse_line(arr_fields_by_id_no[id_registro - 1], line)
    print(tmp_line, file=arr_file_pointers[id_registro - 1])

close_files(arr_file_pointers)
file.close()
