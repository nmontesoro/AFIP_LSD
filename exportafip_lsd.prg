#DEFINE TESTING
#DEFINE CRLF CHR(13) + CHR(10)
#DEFINE MB_ICONSTOP 16
#DEFINE MB_ICONINFORMATION 64

LPARAMETERS sYear AS Char, sMonth AS Char

PRIVATE _nYear, _nMonth, _sPeriod, _nReg04Cnt, _aoFields, _aoConceptos

LOCAL sTxtContent, sSQLStr, lReturnValue

SET TEXTMERGE ON
SET DATE YMD
SET CENTURY ON

*   Fix para el query. Permite hacer SELECT empl, MAX(feclia),... con GROUP BY
*   En realidad me estoy aprovechando de un bug de VFP 7. No es lo correcto,
* pero simplifica bastante algunas cosas.
SET ENGINEBEHAVIOR 70

#IFDEF TESTING
	sYear = "2019"
	sMonth = "7"
#ENDIF

_nYear = INT(VAL(sYear))
_nMonth = INT(VAL(sMonth))
_sPeriod = ALLTRIM(STR(_nYear)) + PADL(ALLTRIM(STR(_nMonth)), 2, "0")
_nReg04Cnt = 0

*   Estos arrays son modificados por las funciones GetFieldStructure y
* GetConceptos.
*   Tienen que ser públicos, porque FoxPro no permite que una función devuelva
* un array.
PUBLIC ARRAY _aoFields[1], _aoConceptos[1]

DIMENSION _aoFields[1]
DIMENSION _aoConceptos[1]

sTxtContent = ""

IF ImportDataFromSICOSS("sijp12\sijp12.mdb") < 0
    MESSAGEBOX("Ocurrió un error al conectar con SICOSS", MB_ICONSTOP)
    RETURN .F.
ENDIF

IF ! MergeData("RECIBOS.DBC")
    MESSAGEBOX("Hay discrepancias entre la cantidad de empleados " ;
                + "del Libro de Sueldos y el SICOSS", MB_ICONSTOP)
    RETURN .F.
ENDIF

*   Guardo el contenido del txt de salida en memoria
FOR nIDRegistro = 2 TO 4
    sTxtContent = sTxtContent + GetRegistros(nIDRegistro)
NEXT

sTxtContent = GetRegistros(1) + sTxtContent
sTxtContent = LEFT(sTxtContent, LEN(sTxtContent) - LEN(CRLF))

lReturnValue = (STRTOFILE(sTxtContent, _sPeriod + ".txt") > 0)

#IFDEF TESTING
	IF lReturnValue
		MESSAGEBOX("Archivo escrito correctamente", MB_ICONINFORMATION)
	ELSE
		MESSAGEBOX("Ocurrió un error - intente nuevamente", MB_ICONSTOP)
	ENDIF

    CLOSE ALL
#ENDIF

RETURN lReturnValue

FUNCTION ImportDataFromSICOSS(sPathDBSICOSS AS String)
*   Conecto a la DB de SICOSS e importo a un cursor.
*   Devuelvo:
*     -1 si hubo un error de conexión (heredado de SQLSTRINGCONNECT)
*     -2 si hubo un error de environment (heredado de SQLSTRINGCONNECT)
*     -3 si hubo un error con el query (propio)
*     >0 si salió todo bien

    LOCAL nSQLConnHandle AS Integer, sQuery AS String, nReturnValue AS Integer

    TEXT TO sSQLStr NOSHOW
DRIVER=Microsoft Access Driver (*.mdb);DBQ=<<sPathDBSICOSS>>;PWD=naDdePraKciN
    ENDTEXT

    nSQLConnHandle = SQLSTRINGCONNECT(sSQLStr)
    nReturnValue = nSQLConnHandle
    sQuery = "SELECT * FROM 22CUILes WHERE [Período]='&_sPeriod.'"

    IF nSQLConnHandle >= 1
        IF ! SQLEXEC(nSQLConnHandle, sQuery, "C_SICOSS") == 1
            nReturnValue = -3
        ENDIF

        *   Intento cerrar la conexión con la DB de SICOSS
        IF SQLDISCONNECT(nSQLConnHandle) <> 1
            ? "WARNING: Imposible cerrar conexión con SICOSS!"
        ENDIF
    ENDIF

    RETURN nReturnValue
ENDFUNC

FUNCTION GetGroupFields()
*   Leo el archivo group_config.txt y devuelvo su contenido

	LOCAL sReturnVal
	
	sReturnVal = ""
	
	IF FILE("LSD\group_config.txt")
		sReturnVal = FILETOSTR("LSD\group_config.txt")
	ENDIF
	
	RETURN sReturnVal
ENDFUNC

FUNCTION MergeData(sDBLocation AS String)
*   Creo un cursor c_Rec con los datos del libro de sueldos y los del SICOSS.
*   Devuelvo:
*     .T. si salió todo bien
*     .F. si la cantidad de empleados no coincide

    LOCAL nEmployeeCnt AS Integer, sRecFields AS Char

    OPEN DATABASE (sDBLocation) SHARED NOUPDATE
    USE recibo AGAIN IN 0

	sRecFields = GetGroupFields()

    SELECT &sRecFields. FROM recibo ;
        WHERE YEAR(feclia) == _nYear AND MONTH(feclia) == _nMonth ;
        GROUP BY empl ;
        INTO CURSOR c_Rec READWRITE

    nEmployeeCnt = _TALLY

    *   Compatibilizo con SICOSS
    UPDATE c_Rec SET cuil = STRTRAN(cuil, "-", "") WHERE .T.

    *   Mezclo con SICOSS
    SELECT r.*, s.* FROM c_Rec r ;
        INNER JOIN C_SICOSS s ;
        ON r.cuil == s.cuil ;
        INTO CURSOR c_Rec READWRITE

    *   Escribo los nombres y tipos de los campos en un archivo
    #IFDEF TESTING
        AFIELDS(aaFields, "c_Rec")
        STRTOFILE("", "LSD\fields.csv", .F.)
        FOR i = 1 TO ALEN(aaFields, 1)
            FOR j = 1 TO 2
                STRTOFILE(aaFields[i, j] + ";", "LSD\fields.csv", .T.)
            NEXT
            STRTOFILE(CRLF, "LSD\fields.csv", .T.)
        NEXT
        RELEASE aaFields
    #ENDIF

    RETURN (nEmployeeCnt == _TALLY)
ENDFUNC

FUNCTION GetRegistros(nIDRegistro AS Integer)
*   Armo el registro requerido segun los parametros definidos en los archivos
* 01, 02, 03 y 04, y segun los conceptos definidos en conceptos
*   Devuelvo:
*     String conteniendo los registros

    LOCAL sLine AS String, sConfigFilePath AS String

    sLine = ""
    sConfigFilePath = "LSD\" + PADL(nIDRegistro, 2, "0") + ".txt"

    GetLineStructure(sConfigFilePath)

    DO CASE
    CASE nIDRegistro == 1
        GO BOTTOM IN c_Rec

        FOR EACH oField IN _aoFields
            sLine = sLine + GetValue(oField)
        NEXT

        sLine = sLine + CRLF
    CASE nIDRegistro == 2 OR nIDRegistro == 4
        GO TOP IN c_Rec
        SCAN
            FOR EACH oField IN _aoFields
                sLine = sLine + GetValue(oField)
            NEXT

            sLine = sLine + CRLF

            IF nIDRegistro == 4
                _nReg04Cnt = _nReg04Cnt + 1
            ENDIF
        ENDSCAN
    CASE nIDRegistro == 3
        GetConceptos("LSD\conceptos.txt")

        GO TOP IN c_Rec
        SCAN
            FOR EACH oConcepto IN _aoConceptos
                IF EVALUATE(oConcepto.sWhen)
                    FOR EACH oField IN _aoFields
                    	WITH oField
                    		DO CASE
                    		CASE .sFieldName == "cantidad"
                    			.sFormula = ALLTRIM(STR(oConcepto.nCantidad))
                    		CASE .sFieldName == "importe"
                    			.sFormula = oConcepto.sFormula
                    		CASE .sFieldName == "cod_concepto"
                    			.sFormula = oConcepto.sCode
                    		CASE .sFieldName == "tipo"
                    			.sFormula = oConcepto.sTipo
                    		ENDCASE
                    	ENDWITH

                        sLine = sLine + GetValue(oField)
                    NEXT

                    sLine = sLine + CRLF
                ENDIF
            NEXT
        ENDSCAN
    ENDCASE

    RETURN sLine
ENDFUNC

FUNCTION GetConceptos(sConceptoFilePath)
*   Abro el archivo conceptos.txt, parseo y modifico el array global
* _aoConceptos
*   Devuelvo .T. o .F., según encuentre o no el archivo

    LOCAL lReturnVal, lCreateArray

    lReturnVal = .F.
    lCreateArray = .T.

    IF FILE(sConceptoFilePath)
        ALINES(asConceptos, FILETOSTR(sConceptoFilePath))

        FOR EACH sField IN asConceptos
            IF LEFT(sField, 1) <> "*" && Ignoro comentarios
                oConcepto = CREATEOBJECT("Concepto")

                WITH oConcepto
                    .sCode = GETWORDNUM(sField, 1, "|")
                    .sFormula = GETWORDNUM(sField, 3, "|")
                    .sTipo = GETWORDNUM(sField, 4, "|")
                    .nCantidad = INT(VAL(GETWORDNUM(sField, 5, "|")))
                    .sWhen = GETWORDNUM(sField, 6, "|")
                ENDWITH

                IF lCreateArray
                    DIMENSION _aoConceptos[1]
                    lCreateArray = .F.
                ELSE
                    DIMENSION _aoConceptos[ALEN(_aoConceptos) + 1]
                ENDIF

                _aoConceptos[ALEN(_aoConceptos)] = oConcepto
            ENDIF
        NEXT

        lReturnVal = .T.
    ENDIF

    RETURN lReturnVal
ENDFUNC

FUNCTION GetLineStructure(sConfigFilePath)
*   Abro el archivo correspondiente al tipo de registro a escribir, parseo y
* modifico el array global _aoFields
*   Devuelvo .T. o .F. según encuentre el archivo

    LOCAL lReturnVal, lCreateArray

    lReturnVal = .F.
    lCreateArray = .T.

    IF FILE(sConfigFilePath)
        ALINES(asFields, FILETOSTR(sConfigFilePath))

        FOR EACH sField IN asFields
            IF LEFT(sField, 1) <> "*" && Ignoro comentarios
                oField = CREATEOBJECT("CustomField")

                WITH oField
                    .sType = GETWORDNUM(sField, 1, "|")
                    .sFieldName = GETWORDNUM(sField, 2, "|")
                    .nLen = INT(VAL(GETWORDNUM(sField, 3, "|")))
                    .sPad = GETWORDNUM(sField, 4, "|")
                    .sFormula = GETWORDNUM(sField, 5, "|")
                    .sReplace = GETWORDNUM(sField, 6, "|")
                    .sReplacement = GETWORDNUM(sField, 7, "|")
                ENDWITH

                IF lCreateArray
                    DIMENSION _aoFields[1]
                    lCreateArray = .F.
                ELSE
                    DIMENSION _aoFields[ALEN(_aoFields) + 1]
                ENDIF

                _aoFields[ALEN(_aoFields)] = oField
            ENDIF
        NEXT

        lReturnVal = .T.
    ENDIF

    RETURN lReturnVal
ENDFUNC

FUNCTION GetValue(oField)
*   Evalúo la fórmula pedida y le doy el formato que corresponda
*   Devuelvo un string conteniendo el valor, con el formato

    LOCAL sPadFrom, sPadChar, sValue

    WITH oField
        sPadFrom = .GetPaddingFrom()
        sPadChar = .GetPaddingCharacter()
        sValue = ALLTRIM(CAST(EVAL(.sFormula) AS Char(64)))
        sValue = CHRTRAN(sValue, .sReplace, .sReplacement)

        IF UPPER(.sType) == "N"
        	sValue = CHRTRAN(sValue, ".", "")
        ENDIF

        * Por si tiene mas caracteres de los pedidos
        sValue = LEFT(sValue, .nLen)

        IF UPPER(sPadFrom) == "L"
            sValue = PADL(sValue, .nLen, sPadChar)
        ELSE
            sValue = PADR(sValue, .nLen, sPadChar)
        ENDIF
    ENDWITH

    RETURN sValue
ENDFUNC

DEFINE CLASS CustomField AS Custom
*   Clase para volcar los parámetros de cada línea de los archivos 01, 02...

    sType = ""
    sFieldName = ""
    nLen = 0
    sPad = ""
    sFormula = ""
    sReplace = ""
    sReplacement = ""

    FUNCTION GetPaddingCharacter()
    *   Devuelvo el caracter a utilizar para el padding
        RETURN LEFT(This.sPad, 1)
    ENDFUNC

    FUNCTION GetPaddingFrom()
    *   Devuelvo la dirección en la cual hacer el padding
        RETURN RIGHT(This.sPad, 1)
    ENDFUNC
ENDDEFINE

DEFINE CLASS Concepto AS Custom
*   Clase para volcar los parámetros de cada línea del archivo conceptos.txt

    sCode = ""
    sFormula = ""
    sTipo = ""
    nCantidad = 0
    sWhen = ""
ENDDEFINE