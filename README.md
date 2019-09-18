# AFIP_LSD
Código para exportar una base de datos de Visual FoxPro al formato de importación del nuevo Libro de Sueldos Digital, de AFIP

## Cómo funciona

1. Toma como parámetro el período de la liquidación.
2. Para cada recibo emitido en el período requerido, guarda en memoria los registros 02, 03 y 04, según lo especificado en los archivos correspondientes.
3. Escribe el registro 01 en la primera línea del archivo de salida.
4. Escribe los registros 02, 03 y 04 en el archivo de salida.
5. Devuelve `.T.` o `.F.` para indicar si el archivo se escribió correctamente.

## Estructura de los archivos de configuración

Los archivos de configuración son `01.txt`, `02.txt`, `03.txt`, `04.txt`, `conceptos.txt` y `group_fields.txt`. Todos tienen que estar presentes en la carpeta LSD.

### Formato de líneas

Es posible escribir comentarios en estos archivos. Se los denota con un **\*** al comienzo de la línea.

Es **muy** importante tener en cuenta los decimales de las operaciones matemáticas, ya que pueden dar resultados indeseados a la hora de importar en el LSD.

#### Para la configuración de los distintos registros

    [*] type|field_name|length|pad|formula|replace|replacement

 - **type** indica el tipo de campo. Los valores posibles son (s)tring y (n)umeric.
 - **field_name** indica el nombre del campo. Sólo para referencia del usuario.
 - **length** indica la longitud del campo en el archivo de texto. 
 En los campos numéricos, este valor incluye los puntos decimales.
 - **pad** indica con qué rellenar los espacios sin utilizar. 
 `char l|r`. `l` o `r` indica si rellenar desde la izquierda o la derecha, respectivamente.
 - **formula** indica la fórmula a utilizar para el valor del campo. Se le pasa directamente a la función `EVALUATE`, de FoxPro, así que puede tomar prácticamente cualquier cosa.
 - **replace** indica los caracteres a reemplazar, y
 - **replacement** los caracteres con los cuales reemplazar.

 En el caso de los registros 03, los siguientes valores para `field_name` se encuentran reservados para casos especiales:

 - `cantidad`
 - `importe`
 - `cod_concepto`
 - `tipo`

#### Para el archivo `conceptos.txt`

    codigo|descripcion|formula|tipo|cantidad|cuando

- **codigo** es el código que se le informa a la AFIP (que tiene que estar dado de alta previamente en el sistema de LSD).
- **descripcion** es sólo para información del usuario. No aparece para nada en el archivo final.
- **formula** es la fórmula a calcular. Se inyecta directamente durante la confección del registro 03, es decir, se le pasa como parámetro a `EVALUATE`.
- **tipo** indica si es ("C")rédito o ("D")ébito.
- **cantidad** indica la cantidad de conceptos (útil para aquellos que sean proporcionales). También se le pasa a `EVALUATE`.
- **cuando** indica una condición que debe cumplirse para que se escriba el concepto (por ejemplo, que el importe sea distinto de cero).

#### Para el archivo `group_config.txt`

Este archivo sirve para indicar qué campos deben estar presentes en el cursor que se genera. Este cursor toma únicamente los datos que correspondan a las liquidaciones del mes y año requeridos, y los agrupa según el empleado.

Por ejemplo, para ejecutar el siguiente query:
    
    SELECT ;
        empl, cuil, SUM(suebas) ;
    FROM recibo ;
    WHERE ;
        MONTH(feclia) == _nMonth AND YEAR(feclia) == _nYear ;
    GROUP BY empl

sólo hace falta escribir los campos en `group_config.txt`. Es decir,

    empl, cuil, SUM(suebas)

#### Variables disponibles

Las siguientes variables pueden ser utilizadas en los archivos de configuración:

 - `_nMonth`: mes especificado por el usuario.
 - `_nYear`: año especificado por el usuario.
 - `_sPeriod`: período especificado por el usuario, en formato AAAAMM.
 - `_nReg04Cnt`: cantidad de registros 04 a informar. El valor de esta variable 
 es 0 hasta que se confecciona el último registro 04, por lo que debe ser 
 usada **únicamente en los registros 01**.

 #### Aclaraciones

 - **replace** y **replacement** toman **de a un caracter a la vez**. No reemplazan palabras enteras.
 - Todos los archivos de configuración **deben finalizar con una línea en blanco**.