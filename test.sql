DECLARE timeout, nombreCola, nomServiceConfig EXTERNAL CHARACTER '';

DECLARE ns NAMESPACE 'http://www.dinersclub.com.ec/iib/soa/esb/clientes/consultas/ConsultaSociosWeb/IntegracionWSCreacionCasosPS';
DECLARE ns30 NAMESPACE 'http://www.dinersclub.com.ec/2016/DinHeader';

/* * Mapea la estructura de entrada. * Parameters: * IN: REFERENCE InputRoot - arbol que contiene los datos de entrada. 
 * RETURNS: BOOLEAN . * */
CREATE COMPUTE MODULE FlujoCreacionCasoPS_ProcesarEntrada
	/* * Funcion que mapea la estructura de entrada. * Parameters: * IN: REFERENCE InputRoot - arbol que contiene los datos de entrada. 
    * RETURNS: BOOLEAN . * */
	CREATE FUNCTION Main() RETURNS BOOLEAN
	BEGIN
		DECLARE dinHeader REFERENCE TO Environment.Header.[ < ];
		DECLARE dinBody REFERENCE TO Environment.Body.[ < ].dinBody;
		
		--CargarUDP
		DECLARE referenciaConf REFERENCE TO Environment;
		CALL diners.utilitarios.CargarServicioConfigurable(nomServiceConfig, referenciaConf);
		DECLARE propiedades REFERENCE TO Environment.cache.service.{nomServiceConfig};
		
		--Manejo de Encriptacion
		IF LENGTH(TRIM(COALESCE(dinBody.numTarjeta, ''))) > 0 THEN
			DECLARE entidades CHARACTER  propiedades.entidadesKey;
			DECLARE aplicacionID CHARACTER dinHeader.ns30:aplicacionID;
			DECLARE nombreUDPKey CHARACTER '';
			IF aplicacionID = 'CHATBOTWSP' THEN
				DECLARE referencia REFERENCE TO Environment;
				SET dinBody.numTarjeta = diners.utilitarios.encriptacion.desencriptar(dinBody.numTarjeta, referencia);
			
			--Validacion de encriptacion
			ELSEIF CONTAINS(entidades, aplicacionID) THEN
				SET nombreUDPKey = propiedades.{'key' || aplicacionID} ;
				DECLARE referencia REFERENCE TO Environment;
				
				CREATE LASTCHILD OF Environment NAME 'Encriptacion';
				DECLARE Encriptacion REFERENCE TO Environment.Encriptacion;  
			
			    SET Encriptacion.nomServiceConfig  	= nombreUDPKey;
				SET Encriptacion.Encriptar			= 'D';
				SET Encriptacion.llaveSimetrica		= dinHeader.ns30:llaveSimetrica;
				
				--Se crea carpeta de Datos para la encriptacion
				CREATE LASTCHILD OF Environment.Encriptacion.listaDatos NAME 'Datos';
				SET Encriptacion.listaDatos.[ < ].valor = dinBody.numTarjeta;
				
				CALL diners.utilitarios.encriptacion.EncriptacionEntidad(referencia);
				SET dinBody.numTarjeta = Environment.Encriptacion.listaDatos.Datos[ 1 ].datoDesencriptado;
			END IF;
		END IF;
		
		--Se inicializan variables de ambiente
		SET Environment.hayError = 0;
		SET Environment.totalPag = 0;
		SET Environment.validarError = 0;
		
		CREATE LASTCHILD OF Environment NAME 'root';
		DECLARE rotear REFERENCE TO Environment.root;  
			
		--Colocar entrada
		DECLARE tipoTransaccion CHARACTER Environment.tipoTransaccion;
		
		IF UPPER(tipoTransaccion) = 'S' THEN
			CREATE LASTCHILD OF Environment NAME 'FlujosSOAP';
			DECLARE FlujosSOAP REFERENCE TO Environment.FlujosSOAP;  
		
			SET FlujosSOAP.URL = propiedades.url;
			SET FlujosSOAP.SOAPAction = propiedades.action;
			SET FlujosSOAP.Timeout = timeout;
			SET Environment.DatosServicio.nsWSSoap = propiedades.nameSpace;
			
			DECLARE nsSoap NAMESPACE Environment.DatosServicio.nsWSSoap;
			DECLARE soapIn REFERENCE TO Environment;
			CREATE LASTCHILD OF Environment.FlujosSOAP.Input AS soapIn NAMESPACE nsSoap NAME propiedades.contenedorRequest;
			
			--Se mapea los datos de entrada
			SET soapIn.CodigoOperacion = 'NEW';
			SET soapIn.SetID = '';
			SET soapIn.CaseID = '';
			SET soapIn.DescripcionOpt = dinBody.codAplicacion || '|' || dinBody.codTransaccion;
			SET soapIn.TemplateID = '';
			SET soapIn.NumeroIdentificacion = dinBody.numDocumento;
			SET soapIn.TipoIdentificacion = dinBody.tipoDocumento;
			SET soapIn.CodAplicacion = COALESCE(dinBody.codAplicacion, '');
			SET soapIn.TipIdentificacion2 = '';
			SET soapIn.CaseType = '';
			SET soapIn.CaseSubtype = '';
			SET soapIn.CodCategoria = '';
			SET soapIn.CodEspecialidad = '';
			SET soapIn.CodDetalle = '';
			SET soapIn.DescripcionCaso = COALESCE(dinBody.descMensaje, '');
			SET soapIn.DescripcionContacto = '';
			SET soapIn.MetodoContacto = '';
			SET soapIn.DireccionEmail = '';
			--Se mapea los datos de entrada
			SET soapIn.CodEntidad = '';
			SET soapIn.CodMarca = '';
			SET soapIn.NumeroCuenta = COALESCE(dinBody.numCuenta, '');
			SET soapIn.NumeroTarjeta = COALESCE(dinBody.numTarjeta, '');
			SET soapIn.IdentificLlamada = '';
			SET soapIn.EstadoCaso = COALESCE(dinBody.estadoCaso, '');
			SET soapIn.DetallePdf = '';
			SET soapIn.FechaLlamada = '';
			SET soapIn.HoraLlamada = '';
			
			SET rotear.tipoTransaccion = 'S';
		ELSE
			CREATE LASTCHILD OF Environment NAME 'FlujosMQ';
			DECLARE FlujosMQ REFERENCE TO Environment.FlujosMQ;  
			
			--Se mapea los datos de la cola
			SET FlujosMQ.NombreCola = nombreCola;
			SET FlujosMQ.Entrada = dinBody;
			
			SET rotear.tipoTransaccion = 'A';
		END IF;

		RETURN TRUE;
	END;
END MODULE;