-- DATOS COMERCIALES DE DEMOSTRACION V1 (entorno no productivo)
-- Aplicar despues de 03_schema_total.sql en una base de demostracion.
-- Inserta un flujo enlazado: productor/finca -> campana -> cliente/contrato ->
-- transporte/chofer -> cosecha/calidad -> carga/guia/recepcion -> factura/cobro.
-- Incluye 3 campanas: Mango facturada/cobrada, Palta en comercial y Uva recibida en planta.
-- Agrega proveedores de Mango, Palta y Uva, 2 clientes y transporte/chofer de demostracion.
-- No trunca ni elimina datos. La transaccion revierte completa ante cualquier error.
-- No ejecutar en produccion: contiene personas, empresas, documentos y movimientos ficticios.

BEGIN;
SET LOCAL search_path = agro, public;

DO $$
DECLARE
  v_admin_persona integer;
  v_chofer_persona integer;
  v_productor_persona integer;
  v_admin integer;
  v_chofer_usuario integer;
  v_mango integer;
  v_kent integer;
  v_nop integer;
  v_campania integer;
  v_proveedor integer;
  v_finca integer;
  v_cxp integer;
  v_cliente integer;
  v_cliente_campania integer;
  v_contrato integer;
  v_entrega integer;
  v_empresa_transporte integer;
  v_vehiculo integer;
  v_chofer integer;
  v_acuerdo integer;
  v_coordinacion integer;
  v_cosecha integer;
  v_carga integer;
  v_proveedor_carga integer;
  v_guia integer;
  v_factura integer;
  v_existente integer;
  v_fecha date := DATE '2026-10-15';
BEGIN
  -- Hace que una segunda ejecucion no duplique el escenario.
  SELECT campania_id INTO v_existente FROM campana
    WHERE nombre = 'Mango de Exportación 2026-2027';
  IF v_existente IS NOT NULL THEN
    RAISE NOTICE 'La campana Mango de Exportacion 2026-2027 ya existe (campania_id=%); no se agregaron filas.', v_existente;
    RETURN;
  END IF;

  -- Identidades demo compatibles con el bootstrap de autenticacion V1.
  -- El backend reemplaza el hash marcador por bcrypt al iniciar.
  SELECT persona_id INTO v_admin_persona FROM persona
    WHERE tipo_documento='DNI' AND numero_documento='40000005';
  IF v_admin_persona IS NULL THEN
    INSERT INTO persona(tipo_documento,numero_documento,nombres,apellidos,correo)
    VALUES ('DNI','40000005','Luis Enrique','Montes','administracion@agroexportadora.example')
    RETURNING persona_id INTO v_admin_persona;
  END IF;
  SELECT usuario_id INTO v_admin FROM usuario WHERE usuario='admin-demo';
  IF v_admin IS NULL THEN
    INSERT INTO usuario(persona_id,rol_id,usuario,password_hash,activo)
    VALUES (v_admin_persona,(SELECT rol_id FROM rol WHERE nombre='Administrador'),
      'admin-demo','$2b$10$epedemopasswordhashforfutureauth',true)
    RETURNING usuario_id INTO v_admin;
  END IF;

  SELECT persona_id INTO v_chofer_persona FROM persona
    WHERE tipo_documento='DNI' AND numero_documento='40000002';
  IF v_chofer_persona IS NULL THEN
    INSERT INTO persona(tipo_documento,numero_documento,nombres,apellidos,correo)
    VALUES ('DNI','40000002','Miguel','Torres Ramos','chofer@epe.com')
    RETURNING persona_id INTO v_chofer_persona;
  END IF;
  SELECT usuario_id INTO v_chofer_usuario FROM usuario WHERE usuario='chofer-demo';
  IF v_chofer_usuario IS NULL THEN
    INSERT INTO usuario(persona_id,rol_id,usuario,password_hash,activo)
    VALUES (v_chofer_persona,(SELECT rol_id FROM rol WHERE nombre='Chofer'),
      'chofer-demo','$2b$10$epedemopasswordhashforfutureauth',true)
    RETURNING usuario_id INTO v_chofer_usuario;
  END IF;

  SELECT fruta_id INTO STRICT v_mango FROM fruta WHERE name='Mango';
  SELECT fruta_derivada_id INTO STRICT v_kent FROM fruta_derivada
    WHERE name='Mango Kent' AND fruta_id=v_mango;
  SELECT norma_id INTO STRICT v_nop FROM norma WHERE codigo='NOP';

  INSERT INTO persona(tipo_documento,numero_documento,nombres,apellidos,telefono,correo)
  VALUES ('DNI','40123456','Rosa','Ramirez Huaman','987654321','rosa.ramirez@agroexportadora.example')
  RETURNING persona_id INTO v_productor_persona;
  INSERT INTO proveedor(nombres,apellido,tipo_documento,nmr_documento,zona,telefono,email,
    codigo_lugar_produccion,nombre_agronomico,densidad_plantacion,distanciamiento,
    frecuencia_riego,nombre_aplicacion,aplicaciones_al_ano,persona_id,activo,fecha_registro)
  VALUES ('Rosa','Ramirez Huaman','DNI','40123456','Tambogrande, Piura','987654321',
    'rosa.ramirez@agroexportadora.example','LP-PIU-2026-0041','Fundo Santa Rosa',400,5,3,
    'Trampa Jackson',6,v_productor_persona,true,v_fecha)
  RETURNING proveedor_id INTO v_proveedor;
  INSERT INTO proveedor_x_fruta(proveedor_id,fruta_id) VALUES (v_proveedor,v_mango);

  INSERT INTO finca(nombre_finca,departamento,provincia,distrito,latitud,longitud,
    ha_total_finca,ha_cultivo,proveedor_id,codigo_lugar_produccion,ubigeo,direccion,
    codigo_establecimiento,fruta_derivada_id,edad_cultivo_anios)
  VALUES ('Fundo Santa Rosa','Piura','Piura','Tambogrande',-4.9266000,-80.3442000,
    20,12,v_proveedor,'LP-PIU-2026-0041','200201','Carretera Tambogrande km 4','0001',v_kent,8)
  RETURNING finca_id INTO v_finca;
  INSERT INTO proveedor_x_fruta_derivada(proveedor_id,fruta_derivada_id)
  VALUES (v_proveedor,v_kent);

  INSERT INTO campana(nombre,fecha_inicio,fecha_fin,estado,requerimiento_comercial,
    fruta_id,temporada,responsable_usuario_id,observaciones)
  VALUES ('Mango de Exportación 2026-2027',DATE '2026-09-01',DATE '2027-02-28',
    'en proceso',1200,v_mango,'2026-2027',v_admin,'Campana de mango para exportacion y abastecimiento nacional.')
  RETURNING campania_id INTO v_campania;
  INSERT INTO campania_x_proveedores(cantidad_proveedor,mtd_ceratitis,
    fruta_convencional_estimado,tipo_proveedor,estado,campania_id,proveedor_id,
    precio_compra_kg,moneda,disponibilidad_desde,disponibilidad_hasta,entrevista_aplica)
  VALUES (1200,0.2857,1000,'productor','validado',v_campania,v_proveedor,
    3.50,'PEN',DATE '2026-09-01',DATE '2027-02-28',false)
  RETURNING cxp_id INTO v_cxp;

  INSERT INTO cliente_negocio(nombre_empresa,nombre_contacto,telefono,ruc,
    correo_corporativo,ubicacion,tipo_cliente,fecha_registro)
  VALUES ('Agroexportadora del Norte SAC','Lucia Torres','014440000','20123456789',
    'compras@agroexportadora.example','Lima, Peru','exportador',v_fecha)
  RETURNING cliente_negocio_id INTO v_cliente;
  INSERT INTO cliente_negocio_campana(documento_url,fecha_registro,ficha_tecnica_url,
    cantidad_kg,kilos_acordados,cliente_negocio_id,campania_id,destino_solicitado,
    entrega_desde,entrega_hasta,observaciones)
  VALUES ('documentos/contratos/CTR-MNG-2026-014.pdf',v_fecha,'documentos/fichas/FT-MNG-KENT-2026.pdf',
    1000,1000,v_cliente,v_campania,'Callao, Peru',v_fecha,DATE '2026-10-20',
    'Contrato de exportacion de mango fresco.')
  RETURNING cliente_negocio_campana_id INTO v_cliente_campania;
  INSERT INTO cliente_negocio_campana_x_fruta_derivada(cliente_negocio_campana_id,fruta_derivada_id)
  VALUES (v_cliente_campania,v_kent);
  INSERT INTO contrato_venta(cliente_negocio_campana_id,numero,canal,fecha,kilos_acordados,
    precio_kg,moneda,estado,condiciones_pago,condiciones_entrega)
  VALUES (v_cliente_campania,'CTR-MNG-2026-014','EXPORTACION',v_fecha,1000,5.50,
    'USD','VIGENTE','Pago contra recepcion','Entrega en planta Callao')
  RETURNING contrato_venta_id INTO v_contrato;
  INSERT INTO entrega_programada(contrato_venta_id,destino,fecha,kilos_programados,observaciones)
  VALUES (v_contrato,'Planta de Procesamiento Callao',v_fecha,1000,'Entrega completa de mango para exportacion')
  RETURNING entrega_programada_id INTO v_entrega;
  INSERT INTO entrega_x_fruta_derivada(entrega_programada_id,fruta_derivada_id,kilos_programados)
  VALUES (v_entrega,v_kent,1000);

  INSERT INTO empresa_transporte_externo(nombre_completo,ruc,correo,numero,
    tipo_transportista,registro_mtc,departamento,provincia,ciudad,activo)
  VALUES ('Transportes Costa Norte SAC','20583147026','operaciones@transportescostanorte.example',
    '016660000','EMPRESA','MTC-15-003548','Lima','Callao','Callao',true)
  RETURNING id_empresa_transporte_externo INTO v_empresa_transporte;
  INSERT INTO vehiculo_externo(placa,volumen,ancho,altura,profundidad,peso_neto,
    peso_bruto,id_empresa_transporte_externo,capacidad_kg)
  VALUES ('B7N-842',35,2.5,2.8,5,4000,12000,v_empresa_transporte,8000)
  RETURNING id_vehiculo_externo INTO v_vehiculo;
  INSERT INTO chofer_transporte_externo(nombre,telefono,correo,id_empresa_transporte_externo,
    persona_id,activo,usuario_id,numero_licencia)
  VALUES ('Miguel Torres Ramos','987654321','chofer@epe.com',
    v_empresa_transporte,v_chofer_persona,true,v_chofer_usuario,'M00012345')
  RETURNING id_chofer_transporte_externo INTO v_chofer;
  INSERT INTO acuerdo_transporte(campania_id,id_empresa_transporte_externo,tipo_pago,
    monto_acordado,fecha_acuerdo,fecha_pago_final,estado,moneda,adelanto_acordado)
  VALUES (v_campania,v_empresa_transporte,'AL_FINAL',650, v_fecha,DATE '2026-10-20',
    'CONFIRMADO','PEN',0)
  RETURNING acuerdo_transporte_id INTO v_acuerdo;
  INSERT INTO coordinacion_entrega(entrega_programada_id,acuerdo_transporte_id,
    id_empresa_transporte_externo,id_vehiculo_externo,id_chofer_transporte_externo,
    inicio_programado,fin_programado,origen_descripcion,condiciones_carga,flete_asignado)
  VALUES (v_entrega,v_acuerdo,v_empresa_transporte,v_vehiculo,v_chofer,
    v_fecha + TIME '06:00',v_fecha + TIME '15:00','Fundo Santa Rosa, Tambogrande',
    'Mantener producto ventilado y protegido',650)
  RETURNING coordinacion_entrega_id INTO v_coordinacion;
  INSERT INTO origen_entrega(coordinacion_entrega_id,cxp_id,finca_id)
  VALUES (v_coordinacion,v_cxp,v_finca);

  INSERT INTO cosecha(entrega_programada_id,codigo_lote,fecha_prevista,kilos_estimados,
    kilos_cosechados,kilos_aceptados,estado,cierre_cosecha_at,observaciones)
  VALUES (v_entrega,'MNG-LOT-2026-081',v_fecha,1000,1000,1000,'CERRADA',
    v_fecha + TIME '05:30','Cosecha cerrada de mango Kent para exportacion.')
  RETURNING cosecha_id INTO v_cosecha;
  INSERT INTO medicion_mtd(cxp_id,medido_at,valor,limite_aplicado,registrado_por_usuario_id,
    trampa_referencia,finca_id,capturas,trampas,dias_exposicion)
  VALUES (v_cxp,v_fecha - INTERVAL '7 days',0.2857,1.0000,v_admin,
    'MTD-MNG-TR-041',v_finca,2,10,7);
  INSERT INTO analisis_calidad(cosecha_id,cxp_id,tipo,fecha_muestreo,estado,
    resultado_texto,observaciones,finca_id)
  VALUES (v_cosecha,v_cxp,'Analisis de residuos',v_fecha - 1,'APROBADO',
    'NEGATIVO','Resultado conforme a los parametros revisados.',v_finca),
    (v_cosecha,v_cxp,'Inspeccion de plagas',v_fecha - 1,'APROBADO',
    'CONFORME','Resultado conforme a los parametros revisados.',v_finca);

  INSERT INTO carga(coordinacion_entrega_id,codigo,fecha_carga,anotador_nombre,
    estado_calidad,viaticos_movilidad,viaticos_insumos,observaciones)
  VALUES (v_coordinacion,'CARGA-MNG-2026-081',v_fecha,'Jose Santos Ramirez','APROBADO',40,20,
    'Carga completa para exportacion.')
  RETURNING carga_id INTO v_carga;
  INSERT INTO proveedor_carga(carga_id,cxp_id,fruta_derivada_id,kilos_cargados,
    precio_compra_kg_aplicado,jabas_cargadas,jabas_vacias)
  VALUES (v_carga,v_cxp,v_kent,1000,3.50,50,0)
  RETURNING proveedor_carga_id INTO v_proveedor_carga;
  INSERT INTO origen_carga(proveedor_carga_id,cxp_id,kilos_origen,finca_id)
  VALUES (v_proveedor_carga,v_cxp,1000,v_finca);
  INSERT INTO guia_remision(carga_id,numero,fecha_inicio_traslado,fecha_entrega_transportista,
    peso_bruto_kg,numero_bultos,finca_partida_id,ubigeo_partida_snapshot,
    direccion_partida_snapshot,establecimiento_partida_snapshot,ubigeo_llegada_snapshot,
    direccion_llegada_snapshot,establecimiento_llegada_snapshot,transportista_documento_snapshot,
    mtc_snapshot,placa_snapshot,conductor_documento_snapshot,conductor_nombre_snapshot,
    conductor_licencia_snapshot,observaciones,contenido,emitida_at)
  VALUES (v_carga,'T001-00012487',v_fecha,v_fecha,1050,50,v_finca,'200201',
    'Carretera Tambogrande km 4','0001','070101','Planta de Procesamiento Callao','0001',
    '20583147026','MTC-15-003548','B7N-842','40000002','Miguel Torres Ramos',
    'M00012345','Guia de traslado de mango Kent a planta de procesamiento.',
    jsonb_build_object('tipo','GUIA_REMISION','estado','EMITIDA'),v_fecha + TIME '06:00')
  RETURNING guia_remision_id INTO v_guia;
  INSERT INTO proveedor_guia(guia_remision_id,carga_id,proveedor_carga_id,kilos_asignados,fincas_ids)
  VALUES (v_guia,v_carga,v_proveedor_carga,1000,jsonb_build_array(v_finca));
  INSERT INTO guia_x_norma(guia_remision_id,norma_id) VALUES (v_guia,v_nop);
  INSERT INTO trazabilidad_transporte(contrato_url,kg_comprados,kg_planta,estado,cxp_id,
    coordinacion_entrega_id,carga_id)
  VALUES ('documentos/transporte/CTR-TR-2026-081.pdf',1000,1000,'llegada',v_cxp,
    v_coordinacion,v_carga);
  INSERT INTO chofer_vehiculo_externo(fecha_asignacion_inicio,fecha_asignacion_final,
    id_vehiculo_externo,id_chofer_transporte_externo,id_trazabilidad_transporte,coordinacion_entrega_id)
  SELECT v_fecha + TIME '06:00',v_fecha + TIME '15:00',v_vehiculo,v_chofer,
    id_trazabilidad_transporte,v_coordinacion FROM trazabilidad_transporte
  WHERE carga_id=v_carga;
  INSERT INTO historial_chofer(coordinacion_entrega_id,carga_id,id_chofer_transporte_externo,
    estado,fecha_hora,observacion)
  VALUES (v_coordinacion,v_carga,v_chofer,'EN_CARGA',v_fecha + TIME '06:00','Inicio de carga'),
    (v_coordinacion,v_carga,v_chofer,'SALIDA',v_fecha + TIME '07:00','Salida de finca'),
    (v_coordinacion,v_carga,v_chofer,'EN_CAMINO',v_fecha + TIME '08:00','Traslado a planta'),
    (v_coordinacion,v_carga,v_chofer,'LLEGADA',v_fecha + TIME '14:00','Llegada a planta'),
    (v_coordinacion,v_carga,v_chofer,'CIERRE',v_fecha + TIME '15:00','Cierre de entrega');

  INSERT INTO recepcion_planta(carga_id,id_chofer_transporte_externo,fecha_recepcion,
    peso_planta_kg,hubo_descarte,descarte_kg,resultado,recepcion_confirmada_at,
    descarga_at,cierre_fisico_at,cierre_administrativo_at,compras,logistica,checklist,documentos)
  VALUES (v_carga,v_chofer,v_fecha + TIME '14:30',1000,false,0,'CONFORME',
    v_fecha + TIME '14:30',v_fecha + TIME '14:45',v_fecha + TIME '15:00',
    v_fecha + TIME '15:00',jsonb_build_array(jsonb_build_object(
      'providerId',v_proveedor,'recognizedQuantity',1000)),
    jsonb_build_object('estado','recibido'),jsonb_build_object('conforme',true),jsonb_build_object('guias',1));
  INSERT INTO factura_venta(carga_id,referencia_preparacion,fecha_preparacion,estado,
    numero_factura,fecha_emision,fecha_vencimiento,kilos_facturados,precio_kg_aplicado,
    moneda,importe_venta,verificada_at,observaciones)
  VALUES (v_carga,'PREP-F001-00012487',v_fecha,'EMITIDA','F001-00012487',v_fecha,
    v_fecha + 30,1000,5.50,'USD',5500,v_fecha + TIME '16:00',
    'Venta de mango Kent, entrega recibida conforme.')
  RETURNING factura_venta_id INTO v_factura;
  INSERT INTO cobro_venta(factura_venta_id,fecha,monto,medio,referencia)
  VALUES (v_factura,v_fecha + 30,5500,'TRANSFERENCIA','TRX-20261114-884201');

  RAISE NOTICE 'Campana Mango de Exportación 2026-2027 insertada. Campania %, carga %, factura %.',
    v_campania,v_carga,v_factura;
END $$;

-- Escenarios adicionales: una campana detenida en comercial y otra en logistica.
DO $$
DECLARE
  v_palta integer;
  v_hass integer;
  v_uva integer;
  v_red_globe integer;
  v_nop integer;
  v_admin integer;
  v_cliente_exportador integer;
  v_cliente_industria integer;
  v_campania_comercial integer;
  v_campania_logistica integer;
  v_persona_luis integer;
  v_persona_maria integer;
  v_persona_camila integer;
  v_proveedor_luis integer;
  v_proveedor_maria integer;
  v_proveedor_camila integer;
  v_finca_luis integer;
  v_finca_camila integer;
  v_cxp_luis integer;
  v_cxp_maria integer;
  v_cxp_camila integer;
  v_cliente_campania integer;
  v_contrato integer;
  v_entrega integer;
  v_empresa integer;
  v_vehiculo integer;
  v_chofer integer;
  v_acuerdo integer;
  v_coordinacion integer;
  v_cosecha integer;
  v_carga integer;
  v_proveedor_carga integer;
  v_guia integer;
  v_existente integer;
  v_existente_uva integer;
  v_fecha date := DATE '2026-10-17';
BEGIN
  SELECT campania_id INTO v_existente FROM campana
    WHERE nombre='Palta de Exportación 2026-2027';
  SELECT campania_id INTO v_existente_uva FROM campana
    WHERE nombre='Uva de Exportación 2026';
  IF v_existente IS NOT NULL AND v_existente_uva IS NOT NULL THEN
    RAISE NOTICE 'Las campanas comerciales y logisticas ya existen; no se agregaron filas.';
    RETURN;
  END IF;
  IF v_existente IS NOT NULL OR v_existente_uva IS NOT NULL THEN
    RAISE EXCEPTION 'La carga de escenarios esta incompleta: existe solo uno de los escenarios Palta/Uva. Revisar la base antes de reintentar.';
  END IF;

  SELECT fruta_id INTO STRICT v_palta FROM fruta WHERE name='Palta';
  SELECT fruta_derivada_id INTO STRICT v_hass FROM fruta_derivada
    WHERE name='Palta Hass' AND fruta_id=v_palta;
  SELECT fruta_id INTO STRICT v_uva FROM fruta WHERE name='Uva';
  SELECT fruta_derivada_id INTO STRICT v_red_globe FROM fruta_derivada
    WHERE name='Red Globe' AND fruta_id=v_uva;
  SELECT norma_id INTO STRICT v_nop FROM norma WHERE codigo='NOP';
  SELECT usuario_id INTO v_admin FROM usuario WHERE usuario='admin-demo';

  -- Clientes compartidos por los dos escenarios nuevos.
  SELECT cliente_negocio_id INTO v_cliente_exportador FROM cliente_negocio
    WHERE ruc='20123456789';
  SELECT cliente_negocio_id INTO v_cliente_industria FROM cliente_negocio
    WHERE ruc='20567890123';
  IF v_cliente_industria IS NULL THEN
    INSERT INTO cliente_negocio(nombre_empresa,nombre_contacto,telefono,ruc,
      correo_corporativo,ubicacion,tipo_cliente,fecha_registro)
    VALUES ('Alimentos del Pacifico SAC','Carlos Mendoza','014440001','20567890123',
      'abastecimiento@alimentos-pacifico.example','Callao, Peru','industria',v_fecha)
    RETURNING cliente_negocio_id INTO v_cliente_industria;
  END IF;

  -- Proveedores de palta: uno productor con finca y uno de acopio.
  INSERT INTO persona(tipo_documento,numero_documento,nombres,apellidos,telefono,correo)
  VALUES ('DNI','40210001','Luis Alberto','Mendoza','987654322','luis.mendoza@productoresdelvalle.example')
  RETURNING persona_id INTO v_persona_luis;
  INSERT INTO proveedor(nombres,apellido,tipo_documento,nmr_documento,zona,telefono,email,
    codigo_lugar_produccion,nombre_agronomico,densidad_plantacion,distanciamiento,
    frecuencia_riego,nombre_aplicacion,aplicaciones_al_ano,persona_id,activo,fecha_registro)
  VALUES ('Luis Alberto','Mendoza','DNI','40210001','Morropón, Piura','987654322',
    'luis.mendoza@productoresdelvalle.example','LP-PIU-2026-0042','Fundo Las Palmeras',350,6,3,
    'Riego tecnificado',4,v_persona_luis,true,v_fecha)
  RETURNING proveedor_id INTO v_proveedor_luis;
  INSERT INTO finca(nombre_finca,departamento,provincia,distrito,latitud,longitud,
    ha_total_finca,ha_cultivo,proveedor_id,codigo_lugar_produccion,ubigeo,direccion,
    codigo_establecimiento,fruta_derivada_id,edad_cultivo_anios)
  VALUES ('Fundo Las Palmeras','Piura','Morropón','Chulucanas',-5.0967000,-80.1620000,
    18,10,v_proveedor_luis,'LP-PIU-2026-0042','200401','Sector Agricola Alto Piura','0002',v_hass,6)
  RETURNING finca_id INTO v_finca_luis;
  INSERT INTO proveedor_x_fruta(proveedor_id,fruta_id) VALUES (v_proveedor_luis,v_palta);
  INSERT INTO proveedor_x_fruta_derivada(proveedor_id,fruta_derivada_id)
  VALUES (v_proveedor_luis,v_hass);

  INSERT INTO persona(tipo_documento,numero_documento,nombres,apellidos,telefono,correo)
  VALUES ('DNI','40210002','Maria Elena','Flores Vega','986123450','maria.flores@productoresdelvalle.example')
  RETURNING persona_id INTO v_persona_maria;
  INSERT INTO proveedor(nombres,apellido,tipo_documento,nmr_documento,zona,telefono,email,
    persona_id,activo,fecha_registro)
  VALUES ('Maria Elena','Flores Vega','DNI','40210002','Sullana, Piura','986123450',
    'maria.flores@productoresdelvalle.example',v_persona_maria,true,v_fecha)
  RETURNING proveedor_id INTO v_proveedor_maria;
  INSERT INTO proveedor_x_fruta(proveedor_id,fruta_id) VALUES (v_proveedor_maria,v_palta);
  INSERT INTO proveedor_x_fruta_derivada(proveedor_id,fruta_derivada_id)
  VALUES (v_proveedor_maria,v_hass);

  INSERT INTO campana(nombre,fecha_inicio,fecha_fin,estado,requerimiento_comercial,
    fruta_id,temporada,responsable_usuario_id,observaciones)
  VALUES ('Palta de Exportación 2026-2027',DATE '2026-09-01',DATE '2027-03-31',
    'en proceso',1800,v_palta,'2026-2027',v_admin,
    'Proveedores y contratos registrados; pendiente coordinar el transporte.')
  RETURNING campania_id INTO v_campania_comercial;
  INSERT INTO campania_x_proveedores(cantidad_proveedor,mtd_ceratitis,
    fruta_convencional_estimado,tipo_proveedor,estado,campania_id,proveedor_id,
    precio_compra_kg,moneda,disponibilidad_desde,disponibilidad_hasta,entrevista_aplica)
  VALUES (1000,0.1200,900,'productor','validado',v_campania_comercial,v_proveedor_luis,
    4.20,'PEN',DATE '2026-09-01',DATE '2027-03-31',false)
  RETURNING cxp_id INTO v_cxp_luis;
  INSERT INTO campania_x_proveedores(cantidad_proveedor,mtd_ceratitis,
    tipo_proveedor,estado,campania_id,proveedor_id,precio_compra_kg,moneda,
    disponibilidad_desde,disponibilidad_hasta,entrevista_aplica)
  VALUES (800,0.1800,'acopio','sin validar',v_campania_comercial,v_proveedor_maria,
    4.00,'PEN',DATE '2026-09-15',DATE '2027-03-15',false)
  RETURNING cxp_id INTO v_cxp_maria;

  INSERT INTO cliente_negocio_campana(fecha_registro,cantidad_kg,kilos_acordados,
    cliente_negocio_id,campania_id,destino_solicitado,observaciones)
  VALUES (v_fecha,1000,1000,v_cliente_exportador,v_campania_comercial,
    'Lima, Peru','Negociacion comercial pendiente de programacion de transporte.')
  RETURNING cliente_negocio_campana_id INTO v_cliente_campania;
  INSERT INTO cliente_negocio_campana_x_fruta_derivada(cliente_negocio_campana_id,fruta_derivada_id)
  VALUES (v_cliente_campania,v_hass);
  INSERT INTO contrato_venta(cliente_negocio_campana_id,numero,canal,fecha,kilos_acordados,
    precio_kg,moneda,estado,condiciones_pago)
  VALUES (v_cliente_campania,'CTR-PAL-2026-021','EXPORTACION',v_fecha,1000,7.25,
    'USD','VIGENTE','Pago a 30 dias')
  RETURNING contrato_venta_id INTO v_contrato;
  INSERT INTO cliente_negocio_campana(fecha_registro,cantidad_kg,kilos_acordados,
    cliente_negocio_id,campania_id,destino_solicitado,observaciones)
  VALUES (v_fecha,500,500,v_cliente_industria,v_campania_comercial,
    'Callao, Peru','Segundo cliente de la campana; entrega por coordinar.')
  RETURNING cliente_negocio_campana_id INTO v_cliente_campania;
  INSERT INTO cliente_negocio_campana_x_fruta_derivada(cliente_negocio_campana_id,fruta_derivada_id)
  VALUES (v_cliente_campania,v_hass);
  INSERT INTO contrato_venta(cliente_negocio_campana_id,numero,canal,fecha,kilos_acordados,
    precio_kg,moneda,estado,condiciones_pago)
  VALUES (v_cliente_campania,'CTR-PAL-2026-022','INDUSTRIA',v_fecha,500,6.10,
    'PEN','VIGENTE','Pago contra entrega');

  -- Proveedor productor de uva y cliente con entrega avanzada a logistica.
  INSERT INTO persona(tipo_documento,numero_documento,nombres,apellidos,telefono,correo)
  VALUES ('DNI','40210003','Camila Torres','Seminario','985555123','camila.torres@vinedosdelnorte.example')
  RETURNING persona_id INTO v_persona_camila;
  INSERT INTO proveedor(nombres,apellido,tipo_documento,nmr_documento,zona,telefono,email,
    codigo_lugar_produccion,nombre_agronomico,densidad_plantacion,distanciamiento,
    frecuencia_riego,nombre_aplicacion,aplicaciones_al_ano,persona_id,activo,fecha_registro)
  VALUES ('Camila Torres','Seminario','DNI','40210003','Sullana, Piura','985555123',
    'camila.torres@vinedosdelnorte.example','LP-PIU-2026-0043','Fundo Los Viñedos',1800,3,2,
    'Riego por goteo',5,v_persona_camila,true,v_fecha)
  RETURNING proveedor_id INTO v_proveedor_camila;
  INSERT INTO finca(nombre_finca,departamento,provincia,distrito,latitud,longitud,
    ha_total_finca,ha_cultivo,proveedor_id,codigo_lugar_produccion,ubigeo,direccion,
    codigo_establecimiento,fruta_derivada_id,edad_cultivo_anios)
  VALUES ('Fundo Los Viñedos','Piura','Sullana','Marcavelica',-4.8778000,-80.7059000,
    16,10,v_proveedor_camila,'LP-PIU-2026-0043','200604','Sector Agricola Alto Piura','0003',v_red_globe,7)
  RETURNING finca_id INTO v_finca_camila;
  INSERT INTO proveedor_x_fruta(proveedor_id,fruta_id) VALUES (v_proveedor_camila,v_uva);
  INSERT INTO proveedor_x_fruta_derivada(proveedor_id,fruta_derivada_id)
  VALUES (v_proveedor_camila,v_red_globe);
  INSERT INTO campana(nombre,fecha_inicio,fecha_fin,estado,requerimiento_comercial,
    fruta_id,temporada,responsable_usuario_id,observaciones)
  VALUES ('Uva de Exportación 2026',DATE '2026-09-01',DATE '2026-12-31',
    'en proceso',800,v_uva,'2026',v_admin,
    'Carga recibida en planta; pendiente preparar la facturacion.')
  RETURNING campania_id INTO v_campania_logistica;
  INSERT INTO campania_x_proveedores(cantidad_proveedor,mtd_ceratitis,
    fruta_convencional_estimado,tipo_proveedor,estado,campania_id,proveedor_id,
    precio_compra_kg,moneda,disponibilidad_desde,disponibilidad_hasta,entrevista_aplica)
  VALUES (800,0.1429,750,'productor','validado',v_campania_logistica,v_proveedor_camila,
    3.20,'PEN',DATE '2026-09-01',DATE '2026-12-31',false)
  RETURNING cxp_id INTO v_cxp_camila;
  INSERT INTO cliente_negocio_campana(fecha_registro,cantidad_kg,kilos_acordados,
    cliente_negocio_id,campania_id,destino_solicitado,entrega_desde,entrega_hasta)
  VALUES (v_fecha,800,800,v_cliente_exportador,v_campania_logistica,
    'Planta de Procesamiento Callao',v_fecha,DATE '2026-10-18')
  RETURNING cliente_negocio_campana_id INTO v_cliente_campania;
  INSERT INTO cliente_negocio_campana_x_fruta_derivada(cliente_negocio_campana_id,fruta_derivada_id)
  VALUES (v_cliente_campania,v_red_globe);
  INSERT INTO contrato_venta(cliente_negocio_campana_id,numero,canal,fecha,kilos_acordados,
    precio_kg,moneda,estado,condiciones_pago)
  VALUES (v_cliente_campania,'CTR-UVA-2026-018','EXPORTACION',v_fecha,800,5.30,
    'USD','VIGENTE','Pago a 30 dias')
  RETURNING contrato_venta_id INTO v_contrato;
  INSERT INTO entrega_programada(contrato_venta_id,destino,fecha,kilos_programados,observaciones)
  VALUES (v_contrato,'Planta de Procesamiento Callao',v_fecha,800,'Recepcion registrada; facturacion pendiente.')
  RETURNING entrega_programada_id INTO v_entrega;
  INSERT INTO entrega_x_fruta_derivada(entrega_programada_id,fruta_derivada_id,kilos_programados)
  VALUES (v_entrega,v_red_globe,800);

  SELECT id_empresa_transporte_externo INTO STRICT v_empresa FROM empresa_transporte_externo
    WHERE ruc='20583147026';
  SELECT id_vehiculo_externo INTO STRICT v_vehiculo FROM vehiculo_externo WHERE placa='B7N-842';
  SELECT id_chofer_transporte_externo INTO STRICT v_chofer FROM chofer_transporte_externo
    WHERE correo='chofer@epe.com';
  INSERT INTO acuerdo_transporte(campania_id,id_empresa_transporte_externo,tipo_pago,
    monto_acordado,fecha_acuerdo,fecha_pago_final,estado,moneda,adelanto_acordado)
  VALUES (v_campania_logistica,v_empresa,'AL_FINAL',520,v_fecha,DATE '2026-10-20',
    'CONFIRMADO','PEN',0)
  RETURNING acuerdo_transporte_id INTO v_acuerdo;
  INSERT INTO coordinacion_entrega(entrega_programada_id,acuerdo_transporte_id,
    id_empresa_transporte_externo,id_vehiculo_externo,id_chofer_transporte_externo,
    inicio_programado,fin_programado,origen_descripcion,condiciones_carga,flete_asignado)
  VALUES (v_entrega,v_acuerdo,v_empresa,v_vehiculo,v_chofer,
    v_fecha + TIME '06:00',v_fecha + TIME '15:00','Fundo Los Viñedos, Marcavelica',
    'Traslado protegido de uva',520)
  RETURNING coordinacion_entrega_id INTO v_coordinacion;
  INSERT INTO origen_entrega(coordinacion_entrega_id,cxp_id,finca_id)
  VALUES (v_coordinacion,v_cxp_camila,v_finca_camila);
  INSERT INTO cosecha(entrega_programada_id,codigo_lote,fecha_prevista,kilos_estimados,
    kilos_cosechados,kilos_aceptados,estado,cierre_cosecha_at,observaciones)
  VALUES (v_entrega,'UVA-LOT-2026-018',v_fecha,800,800,780,'CERRADA',
    v_fecha + TIME '05:30','Lote de uva Red Globe para exportacion.')
  RETURNING cosecha_id INTO v_cosecha;
  INSERT INTO medicion_mtd(cxp_id,medido_at,valor,limite_aplicado,registrado_por_usuario_id,
    trampa_referencia,finca_id,capturas,trampas,dias_exposicion)
  VALUES (v_cxp_camila,v_fecha - INTERVAL '7 days',0.1429,1.0000,v_admin,
    'MTD-UV-TR-018',v_finca_camila,1,10,7);
  INSERT INTO analisis_calidad(cosecha_id,cxp_id,tipo,fecha_muestreo,estado,
    resultado_texto,observaciones,finca_id)
  VALUES (v_cosecha,v_cxp_camila,'Analisis de residuos',v_fecha - 1,'APROBADO',
    'NEGATIVO','Resultado conforme a los parametros revisados.',v_finca_camila),
    (v_cosecha,v_cxp_camila,'Inspeccion de plagas',v_fecha - 1,'APROBADO',
    'CONFORME','Resultado conforme a los parametros revisados.',v_finca_camila);
  INSERT INTO carga(coordinacion_entrega_id,codigo,fecha_carga,anotador_nombre,
    estado_calidad,viaticos_movilidad,viaticos_insumos,observaciones)
  VALUES (v_coordinacion,'CARGA-UVA-2026-018',v_fecha,'Jose Santos Ramirez','APROBADO',35,15,
    'Recepcion conforme; facturacion pendiente.')
  RETURNING carga_id INTO v_carga;
  INSERT INTO proveedor_carga(carga_id,cxp_id,fruta_derivada_id,kilos_cargados,
    precio_compra_kg_aplicado,jabas_cargadas,jabas_vacias)
  VALUES (v_carga,v_cxp_camila,v_red_globe,800,3.20,40,0)
  RETURNING proveedor_carga_id INTO v_proveedor_carga;
  INSERT INTO origen_carga(proveedor_carga_id,cxp_id,kilos_origen,finca_id)
  VALUES (v_proveedor_carga,v_cxp_camila,800,v_finca_camila);
  INSERT INTO guia_remision(carga_id,numero,fecha_inicio_traslado,fecha_entrega_transportista,
    peso_bruto_kg,numero_bultos,finca_partida_id,ubigeo_partida_snapshot,
    direccion_partida_snapshot,establecimiento_partida_snapshot,ubigeo_llegada_snapshot,
    direccion_llegada_snapshot,establecimiento_llegada_snapshot,transportista_documento_snapshot,
    mtc_snapshot,placa_snapshot,conductor_documento_snapshot,conductor_nombre_snapshot,
    conductor_licencia_snapshot,observaciones,contenido,emitida_at)
  VALUES (v_carga,'T001-00000002',v_fecha,v_fecha,830,40,v_finca_camila,'200604',
    'Sector Agricola Alto Piura','0003','070101','Planta de Procesamiento Callao','0001','20583147026',
    'MTC-15-003548','B7N-842','40000002','Miguel Torres Ramos','M00012345',
    'Guia de traslado de uva Red Globe a planta de procesamiento.',jsonb_build_object('tipo','GUIA_REMISION','estado','EMITIDA'),
    v_fecha + TIME '06:00')
  RETURNING guia_remision_id INTO v_guia;
  INSERT INTO proveedor_guia(guia_remision_id,carga_id,proveedor_carga_id,kilos_asignados,fincas_ids)
  VALUES (v_guia,v_carga,v_proveedor_carga,800,jsonb_build_array(v_finca_camila));
  INSERT INTO guia_x_norma(guia_remision_id,norma_id) VALUES (v_guia,v_nop);
  INSERT INTO trazabilidad_transporte(contrato_url,kg_comprados,kg_planta,estado,cxp_id,
    coordinacion_entrega_id,carga_id)
  VALUES ('documentos/transporte/CTR-TR-UVA-2026-018.pdf',800,780,'llegada',v_cxp_camila,
    v_coordinacion,v_carga);
  INSERT INTO chofer_vehiculo_externo(fecha_asignacion_inicio,fecha_asignacion_final,
    id_vehiculo_externo,id_chofer_transporte_externo,id_trazabilidad_transporte,coordinacion_entrega_id)
  SELECT v_fecha + TIME '06:00',v_fecha + TIME '15:00',v_vehiculo,v_chofer,
    id_trazabilidad_transporte,v_coordinacion FROM trazabilidad_transporte
  WHERE carga_id=v_carga;
  INSERT INTO historial_chofer(coordinacion_entrega_id,carga_id,id_chofer_transporte_externo,
    estado,fecha_hora,observacion)
  VALUES (v_coordinacion,v_carga,v_chofer,'EN_CARGA',v_fecha + TIME '06:00','Inicio de carga'),
    (v_coordinacion,v_carga,v_chofer,'SALIDA',v_fecha + TIME '07:00','Salida de finca'),
    (v_coordinacion,v_carga,v_chofer,'EN_CAMINO',v_fecha + TIME '08:00','Traslado a planta'),
    (v_coordinacion,v_carga,v_chofer,'LLEGADA',v_fecha + TIME '14:00','Llegada a planta'),
    (v_coordinacion,v_carga,v_chofer,'CIERRE',v_fecha + TIME '15:00','Cierre de entrega');
  INSERT INTO recepcion_planta(carga_id,id_chofer_transporte_externo,fecha_recepcion,
    peso_planta_kg,hubo_descarte,descarte_kg,resultado,recepcion_confirmada_at,
    descarga_at,cierre_fisico_at,cierre_administrativo_at,compras,logistica,checklist,documentos)
  VALUES (v_carga,v_chofer,v_fecha + TIME '14:30',780,false,0,'CONFORME',
    v_fecha + TIME '14:30',v_fecha + TIME '14:45',v_fecha + TIME '15:00',
    v_fecha + TIME '15:00',jsonb_build_array(jsonb_build_object(
      'providerId',v_proveedor_camila,'recognizedQuantity',780)),
    jsonb_build_object('estado','recibido'),jsonb_build_object('conforme',true),jsonb_build_object('guias',1));

  RAISE NOTICE 'Campanas comerciales y logisticas insertadas: campanas %, %.',
    v_campania_comercial,v_campania_logistica;
END $$;

COMMIT;
