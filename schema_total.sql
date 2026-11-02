-- MODELO DOCUMENTADO PARA REVISION MANUAL. No modifica entidades TypeORM ni la base desplegada.

-- D08 aprobado 2026-10-29: destino de entrega como texto; guía con dirección de llegada histórica; sin catálogo de destinos.

-- Actualización funcional FC01-FC14: tipos/borradores, detalle JSON, recepción reconocida, ajustes y cardinalidades autorizadas.

-- Instalación nueva en agro: incluye 19 tablas actuales y 41 propuestas; catálogos iniciales incluidos; archivo queda excluida.

-- Conserva los nombres de 173 columnas actuales y adapta tipos/nulabilidad para los formularios; retira archivo y campania_x_proveedores.finca_id. Referencias documentales opcionales, sin FK, pendientes de integración.

-- Decisión aprobada 2026-10-27: análisis previo por participación/finca; analisis_calidad.cosecha_id es opcional. Una variedad por finca; fruta se obtiene de la variedad.

-- Participación única campania_x_proveedores; retira puentes derivados y acuerdo_compra. Agrega atributos y 41 tablas propuestas.

-- Se modifican tipos y nulabilidad legacy documentados en modified_columns; no es una migración sobre datos existentes.

-- No es una migración de producción. Si agro existe, se aborta. Requiere btree_gist para la exclusión actual de choferes.

BEGIN;

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;

CREATE SCHEMA agro;

SET LOCAL search_path = agro, public;

CREATE TYPE "campana_estado_enum" AS ENUM ('planificacion', 'en proceso', 'terminado');

CREATE TYPE "campania_x_proveedores_tipo_proveedor_enum" AS ENUM ('acopio', 'productor');

CREATE TYPE "campania_x_proveedores_estado_enum" AS ENUM ('sin validar', 'validado');

CREATE TYPE "certificado_campana_estado_enum" AS ENUM ('vigente', 'por vencer', 'vencida');

CREATE TYPE "cliente_negocio_tipo_cliente_enum" AS ENUM ('exportador', 'industria');

CREATE TYPE "examen_proveedor_resultado_enum" AS ENUM ('positivo', 'negativo');

CREATE TYPE "proveedor_tipo_documento_enum" AS ENUM ('DNI', 'Pasaporte', 'Carnet de extranjeria');

CREATE TYPE "trazabilidad_transporte_estado_enum" AS ENUM ('planificado', 'en recojo', 'despachado', 'llegada');

-- TABLA ACTUAL AMPLIADA: campana

CREATE TABLE "campana" (
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  "campania_id" serial NOT NULL,
  "nombre" varchar NOT NULL,
  "fecha_inicio" date NOT NULL,
  "fecha_fin" date NOT NULL,
  "estado" "campana_estado_enum" NOT NULL DEFAULT 'planificacion'::campana_estado_enum,
  "requerimiento_comercial" numeric(12,3) NOT NULL,
  "fruta_id" integer NOT NULL,
  "temporada" varchar(30),
  "responsable_usuario_id" integer,
  "lineamientos_archivo_id" integer,
  "observaciones" text,
  "cerrada_at" timestamptz,
  "cerrada_por_usuario_id" integer,
  "motivo_cierre" text,
  "calidad" jsonb NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT "PK_e3b63797c6e9a2204d9b3b58f22" PRIMARY KEY (campania_id),
  CHECK (fecha_fin >= fecha_inicio),
  CHECK (jsonb_typeof(calidad) = 'object')
);

-- TABLA ACTUAL AMPLIADA: campania_x_proveedores

CREATE TABLE "campania_x_proveedores" (
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  "cxp_id" serial NOT NULL,
  "cantidad_proveedor" numeric(12,3) NOT NULL,
  "mtd_ceratitis" numeric(12,3),
  "fruta_convencional_estimado" integer,
  "tipo_proveedor" "campania_x_proveedores_tipo_proveedor_enum" NOT NULL,
  "estado" "campania_x_proveedores_estado_enum" NOT NULL DEFAULT 'sin validar'::campania_x_proveedores_estado_enum,
  "campania_id" integer NOT NULL,
  "proveedor_id" integer NOT NULL,
  "precio_compra_kg" numeric(14,4),
  "moneda" varchar(3) NOT NULL DEFAULT 'PEN',
  "disponibilidad_desde" date,
  "disponibilidad_hasta" date,
  "observaciones" text,
  "entrevista_aplica" boolean NOT NULL DEFAULT true,
  CONSTRAINT "CHK_fruta_convencional_solo_productor" CHECK (((tipo_proveedor = 'productor'::campania_x_proveedores_tipo_proveedor_enum) OR (fruta_convencional_estimado IS NULL))),
  CONSTRAINT "PK_fd78570e9beb123e572cbc5914a" PRIMARY KEY (cxp_id),
  CONSTRAINT "UQ_campania_proveedor" UNIQUE (campania_id, proveedor_id),
  CHECK (moneda = 'PEN' AND (precio_compra_kg IS NULL OR precio_compra_kg > 0)),
  CHECK (disponibilidad_hasta >= disponibilidad_desde),
  UNIQUE (cxp_id, campania_id, proveedor_id)
);

-- TABLA ACTUAL AMPLIADA: certificado_campana

CREATE TABLE "certificado_campana" (
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  "certificado_id" serial NOT NULL,
  "nombre" varchar(255) NOT NULL,
  "document_url" text,
  "costo" numeric(12,2) NOT NULL,
  "recibo_url" text,
  "fecha_vencimiento" date,
  "estado" "certificado_campana_estado_enum",
  "campania_id" integer NOT NULL,
  "codigo" varchar(80),
  "norma_id" integer,
  "organismo" varchar(255),
  "fecha_emision" date,
  "moneda" varchar(3),
  "documento_archivo_id" integer,
  "vigencia_desde" date,
  "observaciones" text,
  "historial_cobertura" jsonb NOT NULL DEFAULT '[]'::jsonb,
  "tipo_certificacion" varchar(80),
  "kilos_iniciales" numeric(14,3) CHECK (kilos_iniciales >= 0),
  CONSTRAINT "PK_1856de725430dd73744896b9e4f" PRIMARY KEY (certificado_id),
  CHECK (moneda IS NULL OR moneda IN ('PEN','USD','EUR')),
  CHECK (jsonb_typeof(historial_cobertura) = 'array'),
  CHECK (fecha_vencimiento >= vigencia_desde),
  CHECK (tipo_certificacion IN ('Global GAP','Orgánico USDA','Orgánico UE','Fairtrade','Rainforest Alliance')),
  UNIQUE (certificado_id, campania_id)
);

-- TABLA ACTUAL AMPLIADA: certificado_proveedor

CREATE TABLE "certificado_proveedor" (
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  "certificado_proveedor_id" serial NOT NULL,
  "fecha_revision_senasa" date NOT NULL,
  "nombre" varchar(255) NOT NULL,
  "proveedor_id" integer NOT NULL,
  "documento_archivo_id" integer,
  CONSTRAINT "PK_d76e928004fdb30ebb69febcbc2" PRIMARY KEY (certificado_proveedor_id)
);

-- TABLA ACTUAL AMPLIADA: chofer_transporte_externo

CREATE TABLE "chofer_transporte_externo" (
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  "id_chofer_transporte_externo" serial NOT NULL,
  "nombre" varchar(255) NOT NULL,
  "telefono" varchar(20) NOT NULL,
  "correo" varchar(320),
  "id_empresa_transporte_externo" integer NOT NULL,
  "persona_id" integer,
  "activo" boolean NOT NULL DEFAULT true,
  "usuario_id" integer,
  "numero_licencia" varchar(40),
  CONSTRAINT "PK_chofer_transporte_externo" PRIMARY KEY (id_chofer_transporte_externo),
  UNIQUE (id_chofer_transporte_externo, id_empresa_transporte_externo)
);

-- TABLA ACTUAL AMPLIADA: chofer_vehiculo_externo

CREATE TABLE "chofer_vehiculo_externo" (
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  "id_chofer_vehiculo_externo" serial NOT NULL,
  "fecha_asignacion_inicio" timestamptz NOT NULL,
  "fecha_asignacion_final" timestamptz NOT NULL,
  "id_vehiculo_externo" integer NOT NULL,
  "id_chofer_transporte_externo" integer NOT NULL,
  "id_trazabilidad_transporte" integer NOT NULL,
  "coordinacion_entrega_id" integer,
  CONSTRAINT "CHK_asignacion_fechas_validas" CHECK (fecha_asignacion_final > fecha_asignacion_inicio),
  CONSTRAINT "EX_chofer_sin_rangos_superpuestos" EXCLUDE USING gist (id_chofer_transporte_externo WITH =, tstzrange(fecha_asignacion_inicio, fecha_asignacion_final, '[)') WITH &&),
  CONSTRAINT "PK_chofer_vehiculo_externo" PRIMARY KEY (id_chofer_vehiculo_externo)
);

-- TABLA ACTUAL AMPLIADA: cliente_negocio

CREATE TABLE "cliente_negocio" (
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  "cliente_negocio_id" serial NOT NULL,
  "nombre_empresa" varchar(255) NOT NULL,
  "nombre_contacto" varchar(255) NOT NULL,
  "telefono" varchar(20) NOT NULL,
  "ruc" varchar(11) NOT NULL,
  "correo_corporativo" varchar(320),
  "ubicacion" text NOT NULL,
  "tipo_cliente" "cliente_negocio_tipo_cliente_enum" NOT NULL,
  "fecha_registro" date,
  CONSTRAINT "PK_e6a11c46edc2485ab8547967913" PRIMARY KEY (cliente_negocio_id),
  CONSTRAINT "UQ_086205a1da353930132c0f40b6d" UNIQUE (correo_corporativo),
  CONSTRAINT "UQ_ba980f42b010ee693f6509928b8" UNIQUE (ruc)
);

-- TABLA ACTUAL AMPLIADA: cliente_negocio_campana

CREATE TABLE "cliente_negocio_campana" (
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  "cliente_negocio_campana_id" serial NOT NULL,
  "documento_url" text,
  "fecha_registro" date NOT NULL,
  "ficha_tecnica_url" text,
  "cantidad_kg" numeric(14,3) NOT NULL DEFAULT '0'::numeric,
  "kilos_acordados" numeric(14,3) NOT NULL,
  "cliente_negocio_id" integer NOT NULL,
  "campania_id" integer NOT NULL,
  "ficha_tecnica_archivo_id" integer,
  "destino_solicitado" varchar(255),
  "entrega_desde" date,
  "entrega_hasta" date,
  "observaciones" text,
  CONSTRAINT "PK_f4962041b56eb8097da60768397" PRIMARY KEY (cliente_negocio_campana_id),
  CHECK (entrega_hasta >= entrega_desde)
);

-- TABLA ACTUAL AMPLIADA: detalle_trazabilidad

CREATE TABLE "detalle_trazabilidad" (
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  "id_detalle_trazabilidad" serial NOT NULL,
  "guia_url" text NOT NULL,
  "flete" numeric(12,2) NOT NULL,
  "sctr" varchar(255) NOT NULL,
  "estibas" numeric(12,2) NOT NULL,
  "pasajes" numeric(12,2) NOT NULL,
  "comida" numeric(12,2) NOT NULL,
  "id_trazabilidad_transporte" integer NOT NULL,
  "carga_id" integer,
  "guia_remision_id" integer,
  "sctr_archivo_id" integer,
  CONSTRAINT "CHK_detalle_costos_no_negativos" CHECK (((flete >= (0)::numeric) AND (estibas >= (0)::numeric) AND (pasajes >= (0)::numeric) AND (comida >= (0)::numeric))),
  CONSTRAINT "PK_detalle_trazabilidad" PRIMARY KEY (id_detalle_trazabilidad)
);

-- TABLA ACTUAL AMPLIADA: empresa_transporte_externo

CREATE TABLE "empresa_transporte_externo" (
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  "id_empresa_transporte_externo" serial NOT NULL,
  "nombre_completo" varchar(255) NOT NULL,
  "ruc" varchar(11),
  "correo" varchar(320),
  "numero" varchar(20) NOT NULL,
  "tipo_transportista" varchar(20) NOT NULL DEFAULT 'EMPRESA',
  "tipo_documento" varchar(20),
  "numero_documento" varchar(30),
  "persona_id" integer,
  "registro_mtc" varchar(80),
  "departamento" varchar(100),
  "provincia" varchar(100),
  "ciudad" varchar(100),
  "activo" boolean NOT NULL DEFAULT true,
  CONSTRAINT "PK_empresa_transporte_externo" PRIMARY KEY (id_empresa_transporte_externo),
  CONSTRAINT "UQ_empresa_transporte_correo" UNIQUE (correo),
  CONSTRAINT "UQ_empresa_transporte_ruc" UNIQUE (ruc),
  CHECK (tipo_transportista IN ('EMPRESA','INDEPENDIENTE')),
  CHECK ((tipo_transportista = 'EMPRESA' AND ruc IS NOT NULL AND ruc ~ '^[0-9]{11}$') OR (tipo_transportista = 'INDEPENDIENTE' AND tipo_documento IS NOT NULL AND numero_documento IS NOT NULL AND length(trim(numero_documento)) > 0))
);

-- TABLA ACTUAL AMPLIADA: entrevista_extencion

CREATE TABLE "entrevista_extencion" (
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  "entrevista_id" serial NOT NULL,
  "densidad" numeric(12,3),
  "distanciamiento" numeric(12,3),
  "frecuencia" numeric(12,3),
  "nombre_aplicacion" varchar(255),
  "anio_aplicacion" integer,
  "codigo" varchar(255) NOT NULL,
  "cam_x_prov_id" integer NOT NULL,
  "finca_id" integer NOT NULL,
  "fruta_derivada_id" integer,
  "distanciamiento_descripcion" varchar(60),
  "frecuencia_riego_descripcion" varchar(120),
  "aplicaciones_al_ano" integer,
  "observaciones" text,
  "archivo_id" integer,
  "registrado_por_usuario_id" integer,
  CONSTRAINT "CHK_entrevista_extencion_codigo" CHECK (((codigo)::text ~ '^FVV-[A-Z0-9-]+-[0-9]+$'::text)),
  CONSTRAINT "CHK_entrevista_extencion_valores" CHECK (((densidad >= (0)::numeric) AND (distanciamiento >= (0)::numeric) AND (frecuencia >= (0)::numeric) AND ((anio_aplicacion >= 1900) AND (anio_aplicacion <= 9999)))),
  CONSTRAINT "PK_entrevista_extencion" PRIMARY KEY (entrevista_id),
  CHECK (aplicaciones_al_ano >= 0)
);

-- TABLA ACTUAL AMPLIADA: examen_proveedor

CREATE TABLE "examen_proveedor" (
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  "examen_proveedor_id" serial NOT NULL,
  "fecha" date NOT NULL,
  "tipo_examen" varchar(150) NOT NULL,
  "resultado" "examen_proveedor_resultado_enum",
  "origen" varchar(255),
  "observacion" text,
  "documento_url" text,
  "proveedor_id" integer NOT NULL,
  "cxp_id" integer,
  "finca_id" integer,
  "codigo_muestra" varchar(80),
  "fecha_envio" date,
  "estado_examen" varchar(30) NOT NULL DEFAULT 'Pendiente',
  "documento_archivo_id" integer,
  CONSTRAINT "PK_f59bf88a67c9cf036782197944b" PRIMARY KEY (examen_proveedor_id),
  CHECK (estado_examen IN ('Pendiente','Enviado','Con resultado')),
  CHECK (estado_examen <> 'Con resultado' OR resultado IS NOT NULL)
);

-- TABLA ACTUAL AMPLIADA: finca

CREATE TABLE "finca" (
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  "finca_id" serial NOT NULL,
  "nombre_finca" varchar(255) NOT NULL,
  "departamento" varchar(100) NOT NULL,
  "provincia" varchar(100) NOT NULL,
  "distrito" varchar(100) NOT NULL,
  "latitud" numeric(10,7) NOT NULL,
  "longitud" numeric(10,7) NOT NULL,
  "ha_total_finca" numeric(12,3) NOT NULL,
  "ha_cultivo" numeric(12,3) NOT NULL,
  "proveedor_id" integer NOT NULL,
  "codigo_lugar_produccion" varchar(60),
  "codigo_catastral" varchar(60),
  "ubigeo" varchar(6),
  "direccion" text,
  "codigo_establecimiento" varchar(4),
  "fruta_derivada_id" integer,
  "edad_cultivo_anios" numeric(6,2),
  CONSTRAINT "CHK_finca_hectareas" CHECK (((ha_total_finca >= 0) AND (ha_cultivo >= 0) AND (ha_cultivo <= ha_total_finca))),
  CONSTRAINT "PK_finca" PRIMARY KEY (finca_id),
  CHECK (ubigeo IS NULL OR ubigeo ~ '^[0-9]{6}$'),
  CHECK (edad_cultivo_anios >= 0)
);

-- TABLA ACTUAL AMPLIADA: fruta

CREATE TABLE "fruta" (
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  "fruta_id" serial NOT NULL,
  "name" varchar(150) NOT NULL,
  CONSTRAINT "PK_179f00c93094b7a07e1f9dad0f1" PRIMARY KEY (fruta_id)
);

-- TABLA ACTUAL AMPLIADA: fruta_derivada

CREATE TABLE "fruta_derivada" (
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  "fruta_derivada_id" serial NOT NULL,
  "name" varchar(150) NOT NULL,
  "fruta_id" integer NOT NULL,
  CONSTRAINT "PK_c9143f95b69444a7c62e31abaf2" PRIMARY KEY (fruta_derivada_id)
);

-- TABLA ACTUAL AMPLIADA: proveedor

CREATE TABLE "proveedor" (
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  "proveedor_id" serial NOT NULL,
  "nombres" varchar(150) NOT NULL,
  "apellido" varchar(150) NOT NULL,
  "tipo_documento" "proveedor_tipo_documento_enum" NOT NULL,
  "nmr_documento" varchar(30) NOT NULL,
  "identidad_doc_url" text,
  "zona" text NOT NULL,
  "telefono" varchar(30) NOT NULL,
  "email" varchar(320),
  "codigo_lugar_produccion" varchar(60),
  "nombre_agronomico" varchar(255),
  "densidad_plantacion" numeric(12,3),
  "distanciamiento" numeric(12,3),
  "frecuencia_riego" integer,
  "nombre_aplicacion" varchar(255),
  "aplicaciones_al_ano" integer,
  "estado_examen_sanidad_agraria" varchar(100),
  "persona_id" integer,
  "activo" boolean NOT NULL DEFAULT true,
  "documento_archivo_id" integer,
  "fecha_registro" date,
  CONSTRAINT "PK_b3bd1980252a2b7058e8aadefee" PRIMARY KEY (proveedor_id)
);

-- TABLA ACTUAL AMPLIADA: proveedor_x_fruta

CREATE TABLE "proveedor_x_fruta" (
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  "pxf_id" serial NOT NULL,
  "proveedor_id" integer NOT NULL,
  "fruta_id" integer NOT NULL,
  CONSTRAINT "PK_d550d3fc28cd7d0401fdfb1838c" PRIMARY KEY (pxf_id)
);

-- TABLA ACTUAL AMPLIADA: trazabilidad_transporte

CREATE TABLE "trazabilidad_transporte" (
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  "id_trazabilidad_transporte" serial NOT NULL,
  "contrato_url" text NOT NULL,
  "kg_comprados" numeric(14,3) NOT NULL,
  "kg_planta" numeric(14,3) NOT NULL,
  "estado" "trazabilidad_transporte_estado_enum" NOT NULL,
  "cxp_id" integer NOT NULL,
  "coordinacion_entrega_id" integer,
  "carga_id" integer,
  CONSTRAINT "CHK_trazabilidad_kilos_no_negativos" CHECK (((kg_comprados >= (0)::numeric) AND (kg_planta >= (0)::numeric))),
  CONSTRAINT "PK_trazabilidad_transporte" PRIMARY KEY (id_trazabilidad_transporte)
);

-- TABLA ACTUAL AMPLIADA: vehiculo_externo

CREATE TABLE "vehiculo_externo" (
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  "id_vehiculo_externo" serial NOT NULL,
  "placa" varchar(15) NOT NULL,
  "volumen" numeric(12,3),
  "ancho" numeric(10,3),
  "altura" numeric(10,3),
  "profundidad" numeric(10,3),
  "peso_neto" numeric(14,3),
  "peso_bruto" numeric(14,3),
  "id_empresa_transporte_externo" integer NOT NULL,
  "capacidad_kg" numeric(14,3),
  CONSTRAINT "CHK_vehiculo_dimensiones_positivas" CHECK (((volumen > (0)::numeric) AND (ancho > (0)::numeric) AND (altura > (0)::numeric) AND (profundidad > (0)::numeric))),
  CONSTRAINT "CHK_vehiculo_pesos_validos" CHECK (((peso_neto >= (0)::numeric) AND (peso_bruto >= peso_neto))),
  CONSTRAINT "PK_vehiculo_externo" PRIMARY KEY (id_vehiculo_externo),
  CONSTRAINT "UQ_vehiculo_externo_placa" UNIQUE (placa),
  CHECK (capacidad_kg > 0),
  UNIQUE (id_vehiculo_externo, id_empresa_transporte_externo)
);

-- TABLA PROPUESTA: persona

CREATE TABLE "persona" (
  "persona_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "tipo_documento" varchar(20) NOT NULL,
  "numero_documento" varchar(30) NOT NULL,
  "nombres" varchar(120) NOT NULL,
  "apellidos" varchar(120) NOT NULL,
  "telefono" varchar(30),
  "correo" varchar(180),
  "documento_archivo_id" integer,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tipo_documento, numero_documento)
);

-- TABLA PROPUESTA: rol

CREATE TABLE "rol" (
  "rol_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "nombre" varchar(40) NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  UNIQUE (nombre)
);

-- TABLA PROPUESTA: usuario

CREATE TABLE "usuario" (
  "usuario_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "persona_id" integer NOT NULL,
  "rol_id" integer NOT NULL,
  "usuario" varchar(80) NOT NULL,
  "password_hash" text NOT NULL,
  "activo" boolean NOT NULL DEFAULT true,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  UNIQUE (persona_id),
  UNIQUE (usuario)
);

-- TABLA PROPUESTA: parametro_uit

CREATE TABLE "parametro_uit" (
  "parametro_uit_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "anio" integer NOT NULL,
  "valor" numeric(14,2) NOT NULL,
  "limite_uit" numeric(10,2) NOT NULL,
  "umbral_alerta" numeric(5,4) NOT NULL DEFAULT 0.90,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  UNIQUE (anio),
  CHECK (valor > 0),
  CHECK (limite_uit > 0),
  CHECK (umbral_alerta > 0 AND umbral_alerta <= 1)
);

-- TABLA PROPUESTA: proveedor_x_persona

CREATE TABLE "proveedor_x_persona" (
  "proveedor_x_persona_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "proveedor_id" integer NOT NULL,
  "persona_id" integer NOT NULL,
  "vinculo" varchar(60) NOT NULL,
  "activo" boolean NOT NULL DEFAULT true,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  UNIQUE (proveedor_id, persona_id)
);

-- TABLA PROPUESTA: proveedor_x_fruta_derivada

CREATE TABLE "proveedor_x_fruta_derivada" (
  "proveedor_x_fruta_derivada_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "proveedor_id" integer NOT NULL,
  "fruta_derivada_id" integer NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  UNIQUE (proveedor_id, fruta_derivada_id)
);

-- TABLA PROPUESTA: norma

CREATE TABLE "norma" (
  "norma_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "codigo" varchar(40) NOT NULL,
  "nombre" varchar(180) NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  UNIQUE (codigo)
);

-- TABLA PROPUESTA: certificado_campana_x_proveedor

CREATE TABLE "certificado_campana_x_proveedor" (
  "certificado_campana_x_proveedor_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "certificado_id" integer NOT NULL,
  "campania_id" integer NOT NULL,
  "cxp_id" integer NOT NULL,
  "proveedor_id" integer NOT NULL,
  "kilos_autorizados" numeric(14,3) NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  UNIQUE (certificado_id, cxp_id),
  CHECK (kilos_autorizados > 0)
);

-- TABLA PROPUESTA: ampliacion_certificado_campana

CREATE TABLE "ampliacion_certificado_campana" (
  "ampliacion_certificado_campana_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "certificado_id" integer NOT NULL,
  "fecha" date NOT NULL,
  "kilos_adicionales" numeric(14,3) NOT NULL,
  "referencia" varchar(180) NOT NULL,
  "registrado_por_usuario_id" integer,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  CHECK (kilos_adicionales > 0)
);

-- TABLA PROPUESTA: pago_certificado_campana

CREATE TABLE "pago_certificado_campana" (
  "pago_certificado_campana_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "certificado_id" integer NOT NULL,
  "fecha" date NOT NULL,
  "monto" numeric(14,2) NOT NULL,
  "referencia" varchar(100) NOT NULL,
  "comprobante_id" integer,
  "registrado_por_usuario_id" integer,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  UNIQUE (certificado_id, referencia),
  CHECK (monto > 0)
);

-- TABLA PROPUESTA: cliente_negocio_campana_x_fruta_derivada

CREATE TABLE "cliente_negocio_campana_x_fruta_derivada" (
  "cliente_negocio_campana_x_fruta_derivada_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "cliente_negocio_campana_id" integer NOT NULL,
  "fruta_derivada_id" integer NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  UNIQUE (cliente_negocio_campana_id, fruta_derivada_id)
);

-- TABLA PROPUESTA: contrato_venta

CREATE TABLE "contrato_venta" (
  "contrato_venta_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "cliente_negocio_campana_id" integer NOT NULL,
  "numero" varchar(60) NOT NULL DEFAULT ('CTR-' || gen_random_uuid()::text),
  "canal" varchar(20) NOT NULL,
  "fecha" date NOT NULL,
  "kilos_acordados" numeric(14,3) NOT NULL,
  "precio_kg" numeric(14,4),
  "moneda" varchar(3) NOT NULL,
  "estado" varchar(25) NOT NULL DEFAULT 'VIGENTE',
  "condiciones_pago" text,
  "archivo_id" integer,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  "condiciones_entrega" text,
  "observaciones" text,
  UNIQUE (numero),
  CHECK (kilos_acordados > 0),
  CHECK (precio_kg > 0),
  CHECK (canal IN ('EXPORTACION','INDUSTRIA')),
  CHECK (moneda IN ('PEN','USD','EUR'))
);

-- TABLA PROPUESTA: entrega_programada

CREATE TABLE "entrega_programada" (
  "entrega_programada_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "contrato_venta_id" integer NOT NULL,
  "destino" text NOT NULL,
  "fecha" date NOT NULL,
  "kilos_programados" numeric(14,3) NOT NULL,
  "observaciones" text,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  CHECK (kilos_programados > 0),
  CHECK (btrim(destino) <> '')
);

-- TABLA PROPUESTA: entrega_x_fruta_derivada

CREATE TABLE "entrega_x_fruta_derivada" (
  "entrega_x_fruta_derivada_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "entrega_programada_id" integer NOT NULL,
  "fruta_derivada_id" integer NOT NULL,
  "kilos_programados" numeric(14,3) NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  UNIQUE (entrega_programada_id, fruta_derivada_id),
  CHECK (kilos_programados > 0)
);

-- TABLA PROPUESTA: solicitud_transporte

CREATE TABLE "solicitud_transporte" (
  "solicitud_transporte_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "campania_id" integer NOT NULL,
  "referencia" varchar(100) NOT NULL,
  "fecha" timestamptz NOT NULL DEFAULT now(),
  "origen" text NOT NULL,
  "destino" text NOT NULL,
  "ventana_servicio" varchar(180),
  "cantidad_estimada" varchar(100),
  "caracteristicas_vehiculo" text,
  "condiciones" text,
  "limite_respuesta" timestamptz,
  "mensaje" text,
  "archivo_id" integer,
  "estado" varchar(25) NOT NULL DEFAULT 'BORRADOR',
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  UNIQUE (referencia)
);

-- TABLA PROPUESTA: invitacion_transporte

CREATE TABLE "invitacion_transporte" (
  "invitacion_transporte_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "solicitud_transporte_id" integer NOT NULL,
  "id_empresa_transporte_externo" integer NOT NULL,
  "correo_snapshot" varchar(180),
  "estado" varchar(25) NOT NULL DEFAULT 'INVITADA',
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  UNIQUE (solicitud_transporte_id, id_empresa_transporte_externo)
);

-- TABLA PROPUESTA: cotizacion_transporte

CREATE TABLE "cotizacion_transporte" (
  "cotizacion_transporte_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "invitacion_transporte_id" integer NOT NULL,
  "fecha" date NOT NULL,
  "monto" numeric(14,2) NOT NULL,
  "moneda" varchar(3) NOT NULL,
  "condiciones" text,
  "archivo_id" integer,
  "estado" varchar(25) NOT NULL DEFAULT 'RECIBIDA',
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  "disponibilidad" text,
  CHECK (monto > 0),
  CHECK (moneda IN ('PEN','USD','EUR'))
);

-- TABLA PROPUESTA: acuerdo_transporte

CREATE TABLE "acuerdo_transporte" (
  "acuerdo_transporte_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "campania_id" integer NOT NULL,
  "id_empresa_transporte_externo" integer NOT NULL,
  "cotizacion_transporte_id" integer,
  "tipo_pago" varchar(20),
  "monto_acordado" numeric(14,2),
  "fecha_acuerdo" date,
  "fecha_pago_final" date,
  "archivo_id" integer,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  "estado" varchar(20) NOT NULL DEFAULT 'BORRADOR',
  "moneda" varchar(3) NOT NULL DEFAULT 'PEN',
  "adelanto_acordado" numeric(14,2) NOT NULL DEFAULT 0,
  "referencia_cotizacion" text,
  UNIQUE (campania_id, id_empresa_transporte_externo),
  UNIQUE (acuerdo_transporte_id, id_empresa_transporte_externo),
  CHECK (monto_acordado > 0),
  CHECK (tipo_pago IN ('INMEDIATO','CON_ADELANTO','AL_FINAL')),
  CHECK (estado IN ('BORRADOR','CONFIRMADO') AND moneda = 'PEN'),
  CHECK (estado <> 'CONFIRMADO' OR (tipo_pago IS NOT NULL AND monto_acordado IS NOT NULL AND fecha_acuerdo IS NOT NULL AND fecha_pago_final IS NOT NULL)),
  CHECK (adelanto_acordado >= 0 AND (monto_acordado IS NULL OR adelanto_acordado <= monto_acordado))
);

-- TABLA PROPUESTA: coordinacion_entrega

CREATE TABLE "coordinacion_entrega" (
  "coordinacion_entrega_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "entrega_programada_id" integer NOT NULL,
  "acuerdo_transporte_id" integer NOT NULL,
  "id_empresa_transporte_externo" integer NOT NULL,
  "id_vehiculo_externo" integer NOT NULL,
  "id_chofer_transporte_externo" integer NOT NULL,
  "inicio_programado" timestamptz NOT NULL,
  "fin_programado" timestamptz NOT NULL,
  "origen_descripcion" text NOT NULL,
  "condiciones_carga" text,
  "observaciones" text,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  "flete_asignado" numeric(14,2),
  "observacion_flete" text,
  UNIQUE (entrega_programada_id),
  UNIQUE (coordinacion_entrega_id, entrega_programada_id),
  CHECK (fin_programado >= inicio_programado),
  CHECK (flete_asignado > 0),
  CONSTRAINT "EX_coordinacion_chofer_sin_solape" EXCLUDE USING gist (id_chofer_transporte_externo WITH =, tstzrange(inicio_programado, fin_programado, '[)') WITH &&)
);

-- TABLA PROPUESTA: origen_entrega

CREATE TABLE "origen_entrega" (
  "origen_entrega_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "coordinacion_entrega_id" integer NOT NULL,
  "cxp_id" integer NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  "finca_id" integer NOT NULL,
  UNIQUE (coordinacion_entrega_id, cxp_id, finca_id)
);

-- TABLA PROPUESTA: cosecha

CREATE TABLE "cosecha" (
  "cosecha_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "entrega_programada_id" integer NOT NULL,
  "codigo_lote" varchar(60) NOT NULL,
  "fecha_prevista" date NOT NULL,
  "kilos_estimados" numeric(14,3) NOT NULL,
  "kilos_cosechados" numeric(14,3),
  "kilos_aceptados" numeric(14,3),
  "estado" varchar(30) NOT NULL DEFAULT 'PENDIENTE',
  "cierre_cosecha_at" timestamptz,
  "evidencia_id" integer,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  "organizacion" jsonb NOT NULL DEFAULT '{}'::jsonb,
  "avances" jsonb NOT NULL DEFAULT '[]'::jsonb,
  "cierre" jsonb NOT NULL DEFAULT '{}'::jsonb,
  "industria" jsonb NOT NULL DEFAULT '{}'::jsonb,
  "observaciones" text,
  UNIQUE (codigo_lote),
  CHECK (kilos_estimados >= 0),
  CHECK (kilos_cosechados >= 0),
  CHECK (kilos_aceptados >= 0),
  CHECK (jsonb_typeof(organizacion) = 'object'),
  CHECK (jsonb_typeof(avances) = 'array'),
  CHECK (jsonb_typeof(cierre) = 'object'),
  CHECK (jsonb_typeof(industria) = 'object'),
  UNIQUE (entrega_programada_id)
);

-- TABLA PROPUESTA: analisis_calidad

CREATE TABLE "analisis_calidad" (
  "analisis_calidad_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "cosecha_id" integer,
  "cxp_id" integer NOT NULL,
  "tipo" varchar(100) NOT NULL,
  "fecha_muestreo" date NOT NULL,
  "estado" varchar(30) NOT NULL DEFAULT 'PENDIENTE',
  "resultado_texto" varchar(180),
  "resultado_numerico" numeric(14,4),
  "unidad" varchar(30),
  "archivo_id" integer,
  "observaciones" text,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  "finca_id" integer NOT NULL
);

-- TABLA PROPUESTA: medicion_mtd

CREATE TABLE "medicion_mtd" (
  "medicion_mtd_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "cxp_id" integer NOT NULL,
  "medido_at" timestamptz NOT NULL,
  "valor" numeric(12,4) NOT NULL,
  "limite_aplicado" numeric(12,4) NOT NULL,
  "archivo_id" integer,
  "registrado_por_usuario_id" integer,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  "trampa_referencia" varchar(120),
  "finca_id" integer NOT NULL,
  "capturas" integer,
  "trampas" integer,
  "dias_exposicion" integer,
  CHECK (valor >= 0),
  CHECK (limite_aplicado >= 0),
  CONSTRAINT "CHK_medicion_mtd_conteo_completo" CHECK (
    (capturas IS NULL AND trampas IS NULL AND dias_exposicion IS NULL)
    OR (capturas IS NOT NULL AND capturas >= 0 AND trampas IS NOT NULL AND trampas > 0
      AND dias_exposicion IS NOT NULL AND dias_exposicion > 0)
  )
);

-- TABLA PROPUESTA: carga

CREATE TABLE "carga" (
  "carga_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "coordinacion_entrega_id" integer NOT NULL,
  "codigo" varchar(80) NOT NULL,
  "fecha_carga" date NOT NULL,
  "anotador_nombre" varchar(180) NOT NULL,
  "estado_calidad" varchar(30) NOT NULL DEFAULT 'PENDIENTE',
  "viaticos_movilidad" numeric(14,2) NOT NULL DEFAULT 0,
  "viaticos_insumos" numeric(14,2) NOT NULL DEFAULT 0,
  "guia_salida_id" integer,
  "guia_salida_registrada_at" timestamptz,
  "observaciones" text,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  UNIQUE (coordinacion_entrega_id),
  UNIQUE (codigo),
  UNIQUE (carga_id, coordinacion_entrega_id),
  CHECK (viaticos_movilidad >= 0),
  CHECK (viaticos_insumos >= 0)
);

-- TABLA PROPUESTA: proveedor_carga

CREATE TABLE "proveedor_carga" (
  "proveedor_carga_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "carga_id" integer NOT NULL,
  "cxp_id" integer NOT NULL,
  "fruta_derivada_id" integer NOT NULL,
  "kilos_cargados" numeric(14,3) NOT NULL,
  "precio_compra_kg_aplicado" numeric(14,4),
  "jabas_cargadas" integer NOT NULL DEFAULT 0,
  "jabas_vacias" integer NOT NULL DEFAULT 0,
  "bines_cargados" integer NOT NULL DEFAULT 0,
  "bines_vacios" integer NOT NULL DEFAULT 0,
  "mallas_cargadas" integer NOT NULL DEFAULT 0,
  "mallas_vacias" integer NOT NULL DEFAULT 0,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  UNIQUE (carga_id, cxp_id, fruta_derivada_id),
  UNIQUE (proveedor_carga_id, carga_id),
  CHECK (kilos_cargados > 0),
  CHECK (precio_compra_kg_aplicado > 0),
  CHECK (jabas_cargadas >= 0),
  CHECK (jabas_vacias >= 0),
  CHECK (bines_cargados >= 0),
  CHECK (bines_vacios >= 0),
  CHECK (mallas_cargadas >= 0),
  CHECK (mallas_vacias >= 0)
);

-- TABLA PROPUESTA: origen_carga

CREATE TABLE "origen_carga" (
  "origen_carga_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "proveedor_carga_id" integer NOT NULL,
  "cxp_id" integer NOT NULL,
  "kilos_origen" numeric(14,3),
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  "finca_id" integer NOT NULL,
  UNIQUE (proveedor_carga_id, cxp_id, finca_id),
  CHECK (kilos_origen > 0)
);

-- TABLA PROPUESTA: gasto_carga

CREATE TABLE "gasto_carga" (
  "gasto_carga_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "carga_id" integer NOT NULL,
  "concepto" varchar(150) NOT NULL,
  "monto" numeric(14,2) NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  UNIQUE (carga_id, concepto),
  CHECK (monto >= 0)
);

-- TABLA PROPUESTA: guia_remision

CREATE TABLE "guia_remision" (
  "guia_remision_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "carga_id" integer NOT NULL,
  "numero" varchar(30) NOT NULL,
  "fecha_inicio_traslado" date NOT NULL,
  "fecha_entrega_transportista" date,
  "peso_bruto_kg" numeric(14,3) NOT NULL,
  "unidad_peso" varchar(3) NOT NULL DEFAULT 'KGM',
  "numero_bultos" integer NOT NULL,
  "finca_partida_id" integer NOT NULL,
  "ubigeo_partida_snapshot" varchar(6) NOT NULL,
  "direccion_partida_snapshot" text NOT NULL,
  "establecimiento_partida_snapshot" varchar(4) NOT NULL,
  "ubigeo_llegada_snapshot" varchar(6) NOT NULL,
  "direccion_llegada_snapshot" text NOT NULL,
  "establecimiento_llegada_snapshot" varchar(4) NOT NULL,
  "transportista_documento_snapshot" varchar(30) NOT NULL,
  "mtc_snapshot" varchar(80),
  "placa_snapshot" varchar(15) NOT NULL,
  "conductor_documento_snapshot" varchar(30) NOT NULL,
  "conductor_nombre_snapshot" varchar(180) NOT NULL,
  "conductor_licencia_snapshot" varchar(40) NOT NULL,
  "archivo_id" integer,
  "observaciones" text,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  "contenido" jsonb NOT NULL DEFAULT '{}'::jsonb,
  "emitida_at" timestamptz,
  UNIQUE (numero),
  UNIQUE (guia_remision_id, carga_id),
  CHECK (peso_bruto_kg > 0),
  CHECK (numero_bultos > 0),
  CHECK (unidad_peso = 'KGM'),
  CHECK (jsonb_typeof(contenido) = 'object')
);

-- TABLA PROPUESTA: proveedor_guia

CREATE TABLE "proveedor_guia" (
  "proveedor_guia_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "guia_remision_id" integer NOT NULL,
  "carga_id" integer NOT NULL,
  "proveedor_carga_id" integer NOT NULL,
  "kilos_asignados" numeric(14,3) NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  "fincas_ids" jsonb NOT NULL DEFAULT '[]'::jsonb,
  UNIQUE (guia_remision_id, proveedor_carga_id),
  CHECK (kilos_asignados > 0),
  CHECK (jsonb_typeof(fincas_ids) = 'array')
);

-- TABLA PROPUESTA: guia_x_norma

CREATE TABLE "guia_x_norma" (
  "guia_x_norma_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "guia_remision_id" integer NOT NULL,
  "norma_id" integer NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  UNIQUE (guia_remision_id, norma_id)
);

-- TABLA PROPUESTA: historial_chofer

CREATE TABLE "historial_chofer" (
  "historial_chofer_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "coordinacion_entrega_id" integer NOT NULL,
  "carga_id" integer,
  "id_chofer_transporte_externo" integer NOT NULL,
  "estado" varchar(25) NOT NULL,
  "fecha_hora" timestamptz NOT NULL DEFAULT now(),
  "observacion" text,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  UNIQUE (coordinacion_entrega_id, estado),
  CHECK (estado IN ('EN_CARGA','SALIDA','EN_CAMINO','LLEGADA','CIERRE'))
);

-- TABLA PROPUESTA: recepcion_planta

CREATE TABLE "recepcion_planta" (
  "recepcion_planta_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "carga_id" integer NOT NULL,
  "id_chofer_transporte_externo" integer NOT NULL,
  "fecha_recepcion" timestamptz,
  "peso_planta_kg" numeric(14,3),
  "hubo_descarte" boolean,
  "descarte_kg" numeric(14,3),
  "evidencia_descarte_id" integer,
  "reporte_recepcion_id" integer,
  "resultado" varchar(80),
  "recepcion_confirmada_at" timestamptz,
  "descarte_confirmado_at" timestamptz,
  "jabas_devueltas" integer,
  "jabas_devolucion_at" timestamptz,
  "descarga_at" timestamptz,
  "cierre_fisico_at" timestamptz,
  "cierre_administrativo_at" timestamptz,
  "observaciones" text,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  "compras" jsonb NOT NULL DEFAULT '[]'::jsonb,
  "logistica" jsonb NOT NULL DEFAULT '{}'::jsonb,
  "checklist" jsonb NOT NULL DEFAULT '{}'::jsonb,
  "documentos" jsonb NOT NULL DEFAULT '{}'::jsonb,
  "descarga_inicio_at" timestamptz,
  "descarga_fin_at" timestamptz,
  "jabas_iniciales" integer,
  "jabas_no_aplica" boolean,
  UNIQUE (carga_id),
  CHECK (peso_planta_kg > 0),
  CHECK (descarte_kg >= 0),
  CHECK (jabas_devueltas >= 0),
  CHECK (hubo_descarte IS DISTINCT FROM false OR descarte_kg = 0),
  CHECK (hubo_descarte IS DISTINCT FROM true OR descarte_kg > 0),
  CHECK (jsonb_typeof(compras) = 'array'),
  CHECK (jsonb_typeof(logistica) = 'object'),
  CHECK (jsonb_typeof(checklist) = 'object'),
  CHECK (jsonb_typeof(documentos) = 'object'),
  CHECK (descarga_fin_at >= descarga_inicio_at),
  CHECK (jabas_iniciales >= 0 AND (jabas_iniciales IS NULL OR jabas_devueltas <= jabas_iniciales)),
  CHECK (descarte_kg <= peso_planta_kg)
);

-- TABLA PROPUESTA: liquidacion_proveedor

CREATE TABLE "liquidacion_proveedor" (
  "liquidacion_proveedor_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "carga_id" integer NOT NULL,
  "proveedor_id" integer NOT NULL,
  "persona_liquidacion_id" integer NOT NULL,
  "numero" varchar(40) NOT NULL,
  "fecha" date NOT NULL,
  "importe_compra" numeric(14,2) NOT NULL,
  "valor_uit_aplicado" numeric(14,2) NOT NULL,
  "registrado_por_usuario_id" integer NOT NULL,
  "archivo_id" integer,
  "observaciones" text,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  "kilos_reconocidos" numeric(14,3) NOT NULL,
  "precio_kg_aplicado" numeric(14,4) NOT NULL,
  "moneda" varchar(3) NOT NULL DEFAULT 'PEN',
  "fecha_vencimiento" date,
  "persona_snapshot" jsonb NOT NULL,
  "aviso_uit_confirmado" boolean NOT NULL DEFAULT false,
  "limite_uit_aplicado" numeric(10,2) NOT NULL DEFAULT 75,
  UNIQUE (carga_id, proveedor_id),
  UNIQUE (numero),
  CHECK (importe_compra > 0),
  CHECK (valor_uit_aplicado > 0),
  CHECK (kilos_reconocidos > 0 AND precio_kg_aplicado > 0 AND moneda = 'PEN'),
  CHECK (importe_compra = round(kilos_reconocidos * precio_kg_aplicado, 2)),
  CHECK (jsonb_typeof(persona_snapshot) = 'object'),
  CHECK (limite_uit_aplicado > 0)
);

-- TABLA PROPUESTA: liquidacion_transporte

CREATE TABLE "liquidacion_transporte" (
  "liquidacion_transporte_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "carga_id" integer NOT NULL,
  "numero" varchar(40) NOT NULL,
  "fecha" date NOT NULL,
  "flete" numeric(14,2) NOT NULL,
  "registrado_por_usuario_id" integer NOT NULL,
  "archivo_id" integer,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  "fecha_vencimiento" date,
  "moneda" varchar(3) NOT NULL DEFAULT 'PEN',
  "observaciones" text,
  UNIQUE (carga_id),
  UNIQUE (numero),
  CHECK (flete >= 0),
  CHECK (moneda = 'PEN')
);

-- TABLA PROPUESTA: gasto_transporte

CREATE TABLE "gasto_transporte" (
  "gasto_transporte_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "carga_id" integer NOT NULL,
  "concepto" varchar(150) NOT NULL,
  "monto" numeric(14,2) NOT NULL,
  "origen" varchar(20) NOT NULL,
  "incluido_en_liquidacion" boolean NOT NULL DEFAULT false,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  UNIQUE (carga_id, concepto),
  CHECK (monto >= 0),
  CHECK (origen IN ('VIATICO','REAL'))
);

-- TABLA PROPUESTA: adelanto_transporte

CREATE TABLE "adelanto_transporte" (
  "adelanto_transporte_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "acuerdo_transporte_id" integer NOT NULL,
  "fecha" date NOT NULL,
  "monto" numeric(14,2) NOT NULL,
  "referencia" varchar(100) NOT NULL,
  "comprobante_id" integer,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  UNIQUE (acuerdo_transporte_id, referencia),
  CHECK (monto > 0)
);

-- TABLA PROPUESTA: aplicacion_adelanto

CREATE TABLE "aplicacion_adelanto" (
  "aplicacion_adelanto_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "adelanto_transporte_id" integer NOT NULL,
  "liquidacion_transporte_id" integer NOT NULL,
  "fecha" date NOT NULL,
  "monto" numeric(14,2) NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  UNIQUE (adelanto_transporte_id, liquidacion_transporte_id),
  CHECK (monto > 0)
);

-- TABLA PROPUESTA: factura_venta

CREATE TABLE "factura_venta" (
  "factura_venta_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "carga_id" integer NOT NULL,
  "referencia_preparacion" varchar(40) NOT NULL,
  "fecha_preparacion" date NOT NULL,
  "estado" varchar(25) NOT NULL DEFAULT 'PREPARADA',
  "numero_factura" varchar(80),
  "fecha_emision" date,
  "fecha_vencimiento" date,
  "kilos_facturados" numeric(14,3) NOT NULL,
  "precio_kg_aplicado" numeric(14,4) NOT NULL,
  "moneda" varchar(3) NOT NULL,
  "importe_venta" numeric(14,2) NOT NULL,
  "archivo_id" integer,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  "descuento" numeric(14,2) NOT NULL DEFAULT 0,
  "cargos" numeric(14,2) NOT NULL DEFAULT 0,
  "observaciones" text,
  "verificada_at" timestamptz,
  UNIQUE (referencia_preparacion),
  UNIQUE (numero_factura),
  CHECK (kilos_facturados > 0),
  CHECK (precio_kg_aplicado > 0),
  CHECK (estado IN ('PREPARADA','EMITIDA')),
  CHECK (moneda IN ('PEN','USD','EUR')),
  CHECK (fecha_vencimiento >= fecha_emision),
  CHECK (estado <> 'EMITIDA' OR (numero_factura IS NOT NULL AND fecha_emision IS NOT NULL)),
  CHECK (descuento >= 0 AND cargos >= 0 AND importe_venta > 0),
  CHECK (importe_venta = round(kilos_facturados * precio_kg_aplicado - descuento + cargos, 2))
);

-- TABLA PROPUESTA: pago_proveedor

CREATE TABLE "pago_proveedor" (
  "pago_proveedor_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "liquidacion_proveedor_id" integer NOT NULL,
  "fecha" date NOT NULL,
  "monto" numeric(14,2) NOT NULL,
  "medio" varchar(30) NOT NULL,
  "referencia" varchar(100) NOT NULL,
  "comprobante_id" integer,
  "registrado_por_usuario_id" integer,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  UNIQUE (liquidacion_proveedor_id, referencia),
  CHECK (monto > 0)
);

-- TABLA PROPUESTA: pago_transporte

CREATE TABLE "pago_transporte" (
  "pago_transporte_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "liquidacion_transporte_id" integer NOT NULL,
  "fecha" date NOT NULL,
  "monto" numeric(14,2) NOT NULL,
  "medio" varchar(30) NOT NULL,
  "referencia" varchar(100) NOT NULL,
  "comprobante_id" integer,
  "registrado_por_usuario_id" integer,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  UNIQUE (liquidacion_transporte_id, referencia),
  CHECK (monto > 0)
);

-- TABLA PROPUESTA: cobro_venta

CREATE TABLE "cobro_venta" (
  "cobro_venta_id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "factura_venta_id" integer NOT NULL,
  "fecha" date NOT NULL,
  "monto" numeric(14,2) NOT NULL,
  "medio" varchar(30) NOT NULL,
  "referencia" varchar(100) NOT NULL,
  "comprobante_id" integer,
  "registrado_por_usuario_id" integer,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  UNIQUE (factura_venta_id, referencia),
  CHECK (monto > 0)
);

ALTER TABLE "campana" ADD CONSTRAINT "FK_50c2b822c93d60f0f2ae0de1540" FOREIGN KEY ("fruta_id") REFERENCES "fruta" ("fruta_id") ON DELETE RESTRICT;

ALTER TABLE "campania_x_proveedores" ADD CONSTRAINT "FK_ac67b849df2b51b77be457547cb" FOREIGN KEY ("campania_id") REFERENCES "campana" ("campania_id") ON DELETE RESTRICT;

ALTER TABLE "campania_x_proveedores" ADD CONSTRAINT "FK_ce127d1f9b34a8ff0dfd224c31d" FOREIGN KEY ("proveedor_id") REFERENCES "proveedor" ("proveedor_id") ON DELETE RESTRICT;

ALTER TABLE "certificado_campana" ADD CONSTRAINT "FK_9877363efc7d8431c871eb6f99c" FOREIGN KEY ("campania_id") REFERENCES "campana" ("campania_id") ON DELETE CASCADE;

ALTER TABLE "certificado_proveedor" ADD CONSTRAINT "FK_a6da987f811fd933dd2da1f1567" FOREIGN KEY ("proveedor_id") REFERENCES "proveedor" ("proveedor_id") ON DELETE CASCADE;

ALTER TABLE "chofer_transporte_externo" ADD CONSTRAINT "FK_chofer_empresa_transporte" FOREIGN KEY ("id_empresa_transporte_externo") REFERENCES "empresa_transporte_externo" ("id_empresa_transporte_externo") ON DELETE RESTRICT;

ALTER TABLE "chofer_vehiculo_externo" ADD CONSTRAINT "FK_asignacion_vehiculo" FOREIGN KEY ("id_vehiculo_externo") REFERENCES "vehiculo_externo" ("id_vehiculo_externo") ON DELETE RESTRICT;

ALTER TABLE "chofer_vehiculo_externo" ADD CONSTRAINT "FK_asignacion_chofer" FOREIGN KEY ("id_chofer_transporte_externo") REFERENCES "chofer_transporte_externo" ("id_chofer_transporte_externo") ON DELETE RESTRICT;

ALTER TABLE "chofer_vehiculo_externo" ADD CONSTRAINT "FK_asignacion_trazabilidad" FOREIGN KEY ("id_trazabilidad_transporte") REFERENCES "trazabilidad_transporte" ("id_trazabilidad_transporte") ON DELETE CASCADE;

ALTER TABLE "cliente_negocio_campana" ADD CONSTRAINT "FK_f2e31b3e6ce80e06c9e243de0f7" FOREIGN KEY ("cliente_negocio_id") REFERENCES "cliente_negocio" ("cliente_negocio_id") ON DELETE CASCADE;

ALTER TABLE "cliente_negocio_campana" ADD CONSTRAINT "FK_24f10c8e1468fe98f4ca11af600" FOREIGN KEY ("campania_id") REFERENCES "campana" ("campania_id") ON DELETE CASCADE;

ALTER TABLE "detalle_trazabilidad" ADD CONSTRAINT "FK_detalle_trazabilidad" FOREIGN KEY ("id_trazabilidad_transporte") REFERENCES "trazabilidad_transporte" ("id_trazabilidad_transporte") ON DELETE CASCADE;

ALTER TABLE "entrevista_extencion" ADD CONSTRAINT "FK_entrevista_extencion_cxp" FOREIGN KEY ("cam_x_prov_id") REFERENCES "campania_x_proveedores" ("cxp_id") ON DELETE RESTRICT;

ALTER TABLE "entrevista_extencion" ADD CONSTRAINT "FK_entrevista_extencion_finca" FOREIGN KEY ("finca_id") REFERENCES "finca" ("finca_id") ON DELETE RESTRICT;

ALTER TABLE "examen_proveedor" ADD CONSTRAINT "FK_830ef4ed7b9bc939e534a21c919" FOREIGN KEY ("proveedor_id") REFERENCES "proveedor" ("proveedor_id") ON DELETE CASCADE;

ALTER TABLE "finca" ADD CONSTRAINT "FK_finca_proveedor" FOREIGN KEY ("proveedor_id") REFERENCES "proveedor" ("proveedor_id") ON DELETE RESTRICT;

ALTER TABLE "fruta_derivada" ADD CONSTRAINT "FK_eb7b4cc85ee0796f06cc8efdba6" FOREIGN KEY ("fruta_id") REFERENCES "fruta" ("fruta_id") ON DELETE RESTRICT;

ALTER TABLE "proveedor_x_fruta" ADD CONSTRAINT "FK_47ce26fca664cc2d6fe9e7460c2" FOREIGN KEY ("proveedor_id") REFERENCES "proveedor" ("proveedor_id") ON DELETE CASCADE;

ALTER TABLE "proveedor_x_fruta" ADD CONSTRAINT "FK_22a07009136d9e8d0c1cb3547ae" FOREIGN KEY ("fruta_id") REFERENCES "fruta" ("fruta_id") ON DELETE CASCADE;

ALTER TABLE "trazabilidad_transporte" ADD CONSTRAINT "FK_trazabilidad_campania_proveedor" FOREIGN KEY ("cxp_id") REFERENCES "campania_x_proveedores" ("cxp_id") ON DELETE RESTRICT;

ALTER TABLE "vehiculo_externo" ADD CONSTRAINT "FK_vehiculo_empresa_transporte" FOREIGN KEY ("id_empresa_transporte_externo") REFERENCES "empresa_transporte_externo" ("id_empresa_transporte_externo") ON DELETE RESTRICT;

ALTER TABLE "pago_proveedor" ADD CONSTRAINT "fk_revision_22" FOREIGN KEY ("liquidacion_proveedor_id") REFERENCES "liquidacion_proveedor" ("liquidacion_proveedor_id") ON DELETE RESTRICT;

ALTER TABLE "pago_transporte" ADD CONSTRAINT "fk_revision_23" FOREIGN KEY ("liquidacion_transporte_id") REFERENCES "liquidacion_transporte" ("liquidacion_transporte_id") ON DELETE RESTRICT;

ALTER TABLE "cobro_venta" ADD CONSTRAINT "fk_revision_24" FOREIGN KEY ("factura_venta_id") REFERENCES "factura_venta" ("factura_venta_id") ON DELETE RESTRICT;

ALTER TABLE "usuario" ADD CONSTRAINT "fk_revision_25" FOREIGN KEY ("persona_id") REFERENCES "persona" ("persona_id") ON DELETE RESTRICT;

ALTER TABLE "usuario" ADD CONSTRAINT "fk_revision_26" FOREIGN KEY ("rol_id") REFERENCES "rol" ("rol_id") ON DELETE RESTRICT;

ALTER TABLE "proveedor_x_persona" ADD CONSTRAINT "fk_revision_27" FOREIGN KEY ("proveedor_id") REFERENCES "proveedor" ("proveedor_id") ON DELETE RESTRICT;

ALTER TABLE "proveedor_x_persona" ADD CONSTRAINT "fk_revision_28" FOREIGN KEY ("persona_id") REFERENCES "persona" ("persona_id") ON DELETE RESTRICT;

ALTER TABLE "proveedor_x_fruta_derivada" ADD CONSTRAINT "fk_revision_29" FOREIGN KEY ("proveedor_id") REFERENCES "proveedor" ("proveedor_id") ON DELETE RESTRICT;

ALTER TABLE "proveedor_x_fruta_derivada" ADD CONSTRAINT "fk_revision_30" FOREIGN KEY ("fruta_derivada_id") REFERENCES "fruta_derivada" ("fruta_derivada_id") ON DELETE RESTRICT;

ALTER TABLE "certificado_campana_x_proveedor" ADD CONSTRAINT "fk_revision_31" FOREIGN KEY ("certificado_id") REFERENCES "certificado_campana" ("certificado_id") ON DELETE RESTRICT;

ALTER TABLE "certificado_campana_x_proveedor" ADD CONSTRAINT "fk_revision_32" FOREIGN KEY ("campania_id") REFERENCES "campana" ("campania_id") ON DELETE RESTRICT;

ALTER TABLE "certificado_campana_x_proveedor" ADD CONSTRAINT "fk_revision_33" FOREIGN KEY ("cxp_id") REFERENCES "campania_x_proveedores" ("cxp_id") ON DELETE RESTRICT;

ALTER TABLE "certificado_campana_x_proveedor" ADD CONSTRAINT "fk_revision_34" FOREIGN KEY ("proveedor_id") REFERENCES "proveedor" ("proveedor_id") ON DELETE RESTRICT;

ALTER TABLE "ampliacion_certificado_campana" ADD CONSTRAINT "fk_revision_35" FOREIGN KEY ("certificado_id") REFERENCES "certificado_campana" ("certificado_id") ON DELETE RESTRICT;

ALTER TABLE "ampliacion_certificado_campana" ADD CONSTRAINT "fk_revision_36" FOREIGN KEY ("registrado_por_usuario_id") REFERENCES "usuario" ("usuario_id") ON DELETE RESTRICT;

ALTER TABLE "pago_certificado_campana" ADD CONSTRAINT "fk_revision_37" FOREIGN KEY ("certificado_id") REFERENCES "certificado_campana" ("certificado_id") ON DELETE RESTRICT;

ALTER TABLE "pago_certificado_campana" ADD CONSTRAINT "fk_revision_38" FOREIGN KEY ("registrado_por_usuario_id") REFERENCES "usuario" ("usuario_id") ON DELETE RESTRICT;

ALTER TABLE "cliente_negocio_campana_x_fruta_derivada" ADD CONSTRAINT "fk_revision_39" FOREIGN KEY ("cliente_negocio_campana_id") REFERENCES "cliente_negocio_campana" ("cliente_negocio_campana_id") ON DELETE RESTRICT;

ALTER TABLE "cliente_negocio_campana_x_fruta_derivada" ADD CONSTRAINT "fk_revision_40" FOREIGN KEY ("fruta_derivada_id") REFERENCES "fruta_derivada" ("fruta_derivada_id") ON DELETE RESTRICT;

ALTER TABLE "contrato_venta" ADD CONSTRAINT "fk_revision_41" FOREIGN KEY ("cliente_negocio_campana_id") REFERENCES "cliente_negocio_campana" ("cliente_negocio_campana_id") ON DELETE RESTRICT;

ALTER TABLE "entrega_programada" ADD CONSTRAINT "fk_revision_42" FOREIGN KEY ("contrato_venta_id") REFERENCES "contrato_venta" ("contrato_venta_id") ON DELETE RESTRICT;

ALTER TABLE "entrega_x_fruta_derivada" ADD CONSTRAINT "fk_revision_43" FOREIGN KEY ("entrega_programada_id") REFERENCES "entrega_programada" ("entrega_programada_id") ON DELETE RESTRICT;

ALTER TABLE "entrega_x_fruta_derivada" ADD CONSTRAINT "fk_revision_44" FOREIGN KEY ("fruta_derivada_id") REFERENCES "fruta_derivada" ("fruta_derivada_id") ON DELETE RESTRICT;

ALTER TABLE "solicitud_transporte" ADD CONSTRAINT "fk_revision_45" FOREIGN KEY ("campania_id") REFERENCES "campana" ("campania_id") ON DELETE RESTRICT;

ALTER TABLE "invitacion_transporte" ADD CONSTRAINT "fk_revision_46" FOREIGN KEY ("solicitud_transporte_id") REFERENCES "solicitud_transporte" ("solicitud_transporte_id") ON DELETE RESTRICT;

ALTER TABLE "invitacion_transporte" ADD CONSTRAINT "fk_revision_47" FOREIGN KEY ("id_empresa_transporte_externo") REFERENCES "empresa_transporte_externo" ("id_empresa_transporte_externo") ON DELETE RESTRICT;

ALTER TABLE "cotizacion_transporte" ADD CONSTRAINT "fk_revision_48" FOREIGN KEY ("invitacion_transporte_id") REFERENCES "invitacion_transporte" ("invitacion_transporte_id") ON DELETE RESTRICT;

ALTER TABLE "acuerdo_transporte" ADD CONSTRAINT "fk_revision_49" FOREIGN KEY ("campania_id") REFERENCES "campana" ("campania_id") ON DELETE RESTRICT;

ALTER TABLE "acuerdo_transporte" ADD CONSTRAINT "fk_revision_50" FOREIGN KEY ("id_empresa_transporte_externo") REFERENCES "empresa_transporte_externo" ("id_empresa_transporte_externo") ON DELETE RESTRICT;

ALTER TABLE "acuerdo_transporte" ADD CONSTRAINT "fk_revision_51" FOREIGN KEY ("cotizacion_transporte_id") REFERENCES "cotizacion_transporte" ("cotizacion_transporte_id") ON DELETE RESTRICT;

ALTER TABLE "coordinacion_entrega" ADD CONSTRAINT "fk_revision_52" FOREIGN KEY ("entrega_programada_id") REFERENCES "entrega_programada" ("entrega_programada_id") ON DELETE RESTRICT;

ALTER TABLE "coordinacion_entrega" ADD CONSTRAINT "fk_revision_53" FOREIGN KEY ("acuerdo_transporte_id") REFERENCES "acuerdo_transporte" ("acuerdo_transporte_id") ON DELETE RESTRICT;

ALTER TABLE "coordinacion_entrega" ADD CONSTRAINT "fk_revision_54" FOREIGN KEY ("id_empresa_transporte_externo") REFERENCES "empresa_transporte_externo" ("id_empresa_transporte_externo") ON DELETE RESTRICT;

ALTER TABLE "coordinacion_entrega" ADD CONSTRAINT "fk_revision_55" FOREIGN KEY ("id_chofer_transporte_externo") REFERENCES "chofer_transporte_externo" ("id_chofer_transporte_externo") ON DELETE RESTRICT;

ALTER TABLE "origen_entrega" ADD CONSTRAINT "fk_revision_56" FOREIGN KEY ("coordinacion_entrega_id") REFERENCES "coordinacion_entrega" ("coordinacion_entrega_id") ON DELETE RESTRICT;

ALTER TABLE "origen_entrega" ADD CONSTRAINT "fk_revision_57" FOREIGN KEY ("cxp_id") REFERENCES "campania_x_proveedores" ("cxp_id") ON DELETE RESTRICT;

ALTER TABLE "cosecha" ADD CONSTRAINT "fk_revision_58" FOREIGN KEY ("entrega_programada_id") REFERENCES "entrega_programada" ("entrega_programada_id") ON DELETE RESTRICT;

ALTER TABLE "analisis_calidad" ADD CONSTRAINT "fk_revision_59" FOREIGN KEY ("cosecha_id") REFERENCES "cosecha" ("cosecha_id") ON DELETE RESTRICT;

ALTER TABLE "analisis_calidad" ADD CONSTRAINT "fk_revision_60" FOREIGN KEY ("cxp_id") REFERENCES "campania_x_proveedores" ("cxp_id") ON DELETE RESTRICT;

ALTER TABLE "medicion_mtd" ADD CONSTRAINT "fk_revision_61" FOREIGN KEY ("cxp_id") REFERENCES "campania_x_proveedores" ("cxp_id") ON DELETE RESTRICT;

ALTER TABLE "medicion_mtd" ADD CONSTRAINT "fk_revision_62" FOREIGN KEY ("registrado_por_usuario_id") REFERENCES "usuario" ("usuario_id") ON DELETE RESTRICT;

ALTER TABLE "carga" ADD CONSTRAINT "fk_revision_63" FOREIGN KEY ("coordinacion_entrega_id") REFERENCES "coordinacion_entrega" ("coordinacion_entrega_id") ON DELETE RESTRICT;

ALTER TABLE "proveedor_carga" ADD CONSTRAINT "fk_revision_64" FOREIGN KEY ("carga_id") REFERENCES "carga" ("carga_id") ON DELETE RESTRICT;

ALTER TABLE "proveedor_carga" ADD CONSTRAINT "fk_revision_65" FOREIGN KEY ("cxp_id") REFERENCES "campania_x_proveedores" ("cxp_id") ON DELETE RESTRICT;

ALTER TABLE "proveedor_carga" ADD CONSTRAINT "fk_revision_66" FOREIGN KEY ("fruta_derivada_id") REFERENCES "fruta_derivada" ("fruta_derivada_id") ON DELETE RESTRICT;

ALTER TABLE "origen_carga" ADD CONSTRAINT "fk_revision_67" FOREIGN KEY ("proveedor_carga_id") REFERENCES "proveedor_carga" ("proveedor_carga_id") ON DELETE RESTRICT;

ALTER TABLE "origen_carga" ADD CONSTRAINT "fk_revision_68" FOREIGN KEY ("cxp_id") REFERENCES "campania_x_proveedores" ("cxp_id") ON DELETE RESTRICT;

ALTER TABLE "gasto_carga" ADD CONSTRAINT "fk_revision_69" FOREIGN KEY ("carga_id") REFERENCES "carga" ("carga_id") ON DELETE RESTRICT;

ALTER TABLE "guia_remision" ADD CONSTRAINT "fk_revision_70" FOREIGN KEY ("carga_id") REFERENCES "carga" ("carga_id") ON DELETE RESTRICT;

ALTER TABLE "guia_remision" ADD CONSTRAINT "fk_revision_71" FOREIGN KEY ("finca_partida_id") REFERENCES "finca" ("finca_id") ON DELETE RESTRICT;

ALTER TABLE "proveedor_guia" ADD CONSTRAINT "fk_revision_72" FOREIGN KEY ("guia_remision_id") REFERENCES "guia_remision" ("guia_remision_id") ON DELETE RESTRICT;

ALTER TABLE "proveedor_guia" ADD CONSTRAINT "fk_revision_73" FOREIGN KEY ("carga_id") REFERENCES "carga" ("carga_id") ON DELETE RESTRICT;

ALTER TABLE "proveedor_guia" ADD CONSTRAINT "fk_revision_74" FOREIGN KEY ("proveedor_carga_id") REFERENCES "proveedor_carga" ("proveedor_carga_id") ON DELETE RESTRICT;

ALTER TABLE "guia_x_norma" ADD CONSTRAINT "fk_revision_75" FOREIGN KEY ("guia_remision_id") REFERENCES "guia_remision" ("guia_remision_id") ON DELETE RESTRICT;

ALTER TABLE "guia_x_norma" ADD CONSTRAINT "fk_revision_76" FOREIGN KEY ("norma_id") REFERENCES "norma" ("norma_id") ON DELETE RESTRICT;

ALTER TABLE "historial_chofer" ADD CONSTRAINT "fk_revision_77" FOREIGN KEY ("coordinacion_entrega_id") REFERENCES "coordinacion_entrega" ("coordinacion_entrega_id") ON DELETE RESTRICT;

ALTER TABLE "historial_chofer" ADD CONSTRAINT "fk_revision_78" FOREIGN KEY ("carga_id") REFERENCES "carga" ("carga_id") ON DELETE RESTRICT;

ALTER TABLE "historial_chofer" ADD CONSTRAINT "fk_revision_79" FOREIGN KEY ("id_chofer_transporte_externo") REFERENCES "chofer_transporte_externo" ("id_chofer_transporte_externo") ON DELETE RESTRICT;

ALTER TABLE "recepcion_planta" ADD CONSTRAINT "fk_revision_80" FOREIGN KEY ("carga_id") REFERENCES "carga" ("carga_id") ON DELETE RESTRICT;

ALTER TABLE "recepcion_planta" ADD CONSTRAINT "fk_revision_81" FOREIGN KEY ("id_chofer_transporte_externo") REFERENCES "chofer_transporte_externo" ("id_chofer_transporte_externo") ON DELETE RESTRICT;

ALTER TABLE "liquidacion_proveedor" ADD CONSTRAINT "fk_revision_82" FOREIGN KEY ("carga_id") REFERENCES "carga" ("carga_id") ON DELETE RESTRICT;

ALTER TABLE "liquidacion_proveedor" ADD CONSTRAINT "fk_revision_83" FOREIGN KEY ("proveedor_id") REFERENCES "proveedor" ("proveedor_id") ON DELETE RESTRICT;

ALTER TABLE "liquidacion_proveedor" ADD CONSTRAINT "fk_revision_84" FOREIGN KEY ("registrado_por_usuario_id") REFERENCES "usuario" ("usuario_id") ON DELETE RESTRICT;

ALTER TABLE "liquidacion_transporte" ADD CONSTRAINT "fk_revision_85" FOREIGN KEY ("carga_id") REFERENCES "carga" ("carga_id") ON DELETE RESTRICT;

ALTER TABLE "liquidacion_transporte" ADD CONSTRAINT "fk_revision_86" FOREIGN KEY ("registrado_por_usuario_id") REFERENCES "usuario" ("usuario_id") ON DELETE RESTRICT;

ALTER TABLE "gasto_transporte" ADD CONSTRAINT "fk_revision_87" FOREIGN KEY ("carga_id") REFERENCES "carga" ("carga_id") ON DELETE RESTRICT;

ALTER TABLE "adelanto_transporte" ADD CONSTRAINT "fk_revision_88" FOREIGN KEY ("acuerdo_transporte_id") REFERENCES "acuerdo_transporte" ("acuerdo_transporte_id") ON DELETE RESTRICT;

ALTER TABLE "aplicacion_adelanto" ADD CONSTRAINT "fk_revision_89" FOREIGN KEY ("adelanto_transporte_id") REFERENCES "adelanto_transporte" ("adelanto_transporte_id") ON DELETE RESTRICT;

ALTER TABLE "factura_venta" ADD CONSTRAINT "fk_revision_90" FOREIGN KEY ("carga_id") REFERENCES "carga" ("carga_id") ON DELETE RESTRICT;

ALTER TABLE "pago_proveedor" ADD CONSTRAINT "fk_revision_91" FOREIGN KEY ("registrado_por_usuario_id") REFERENCES "usuario" ("usuario_id") ON DELETE RESTRICT;

ALTER TABLE "pago_transporte" ADD CONSTRAINT "fk_revision_92" FOREIGN KEY ("registrado_por_usuario_id") REFERENCES "usuario" ("usuario_id") ON DELETE RESTRICT;

ALTER TABLE "cobro_venta" ADD CONSTRAINT "fk_revision_93" FOREIGN KEY ("registrado_por_usuario_id") REFERENCES "usuario" ("usuario_id") ON DELETE RESTRICT;

ALTER TABLE "certificado_campana_x_proveedor" ADD CONSTRAINT "fk_revision_94" FOREIGN KEY ("certificado_id", "campania_id") REFERENCES "certificado_campana" ("certificado_id", "campania_id") ON DELETE RESTRICT;

ALTER TABLE "certificado_campana_x_proveedor" ADD CONSTRAINT "fk_revision_95" FOREIGN KEY ("cxp_id", "campania_id", "proveedor_id") REFERENCES "campania_x_proveedores" ("cxp_id", "campania_id", "proveedor_id") ON DELETE RESTRICT;

ALTER TABLE "coordinacion_entrega" ADD CONSTRAINT "fk_revision_96" FOREIGN KEY ("acuerdo_transporte_id", "id_empresa_transporte_externo") REFERENCES "acuerdo_transporte" ("acuerdo_transporte_id", "id_empresa_transporte_externo") ON DELETE RESTRICT;

ALTER TABLE "coordinacion_entrega" ADD CONSTRAINT "fk_revision_97" FOREIGN KEY ("id_vehiculo_externo", "id_empresa_transporte_externo") REFERENCES "vehiculo_externo" ("id_vehiculo_externo", "id_empresa_transporte_externo") ON DELETE RESTRICT;

ALTER TABLE "coordinacion_entrega" ADD CONSTRAINT "fk_revision_98" FOREIGN KEY ("id_chofer_transporte_externo", "id_empresa_transporte_externo") REFERENCES "chofer_transporte_externo" ("id_chofer_transporte_externo", "id_empresa_transporte_externo") ON DELETE RESTRICT;

ALTER TABLE "historial_chofer" ADD CONSTRAINT "fk_revision_99" FOREIGN KEY ("carga_id", "coordinacion_entrega_id") REFERENCES "carga" ("carga_id", "coordinacion_entrega_id") ON DELETE RESTRICT;

ALTER TABLE "proveedor_guia" ADD CONSTRAINT "fk_revision_100" FOREIGN KEY ("guia_remision_id", "carga_id") REFERENCES "guia_remision" ("guia_remision_id", "carga_id") ON DELETE RESTRICT;

ALTER TABLE "proveedor_guia" ADD CONSTRAINT "fk_revision_101" FOREIGN KEY ("proveedor_carga_id", "carga_id") REFERENCES "proveedor_carga" ("proveedor_carga_id", "carga_id") ON DELETE RESTRICT;

ALTER TABLE "aplicacion_adelanto" ADD CONSTRAINT "fk_revision_102" FOREIGN KEY ("liquidacion_transporte_id") REFERENCES "liquidacion_transporte" ("liquidacion_transporte_id") ON DELETE RESTRICT;

ALTER TABLE "campana" ADD CONSTRAINT "fk_revision_103" FOREIGN KEY ("responsable_usuario_id") REFERENCES "usuario" ("usuario_id") ON DELETE RESTRICT;

ALTER TABLE "campana" ADD CONSTRAINT "fk_revision_104" FOREIGN KEY ("cerrada_por_usuario_id") REFERENCES "usuario" ("usuario_id") ON DELETE RESTRICT;

ALTER TABLE "certificado_campana" ADD CONSTRAINT "fk_revision_105" FOREIGN KEY ("norma_id") REFERENCES "norma" ("norma_id") ON DELETE RESTRICT;

ALTER TABLE "chofer_transporte_externo" ADD CONSTRAINT "fk_revision_106" FOREIGN KEY ("persona_id") REFERENCES "persona" ("persona_id") ON DELETE RESTRICT;

ALTER TABLE "proveedor" ADD CONSTRAINT "fk_revision_107" FOREIGN KEY ("persona_id") REFERENCES "persona" ("persona_id") ON DELETE RESTRICT;

ALTER TABLE "chofer_transporte_externo" ADD CONSTRAINT "fk_revision_108" FOREIGN KEY ("usuario_id") REFERENCES "usuario" ("usuario_id") ON DELETE RESTRICT;

ALTER TABLE "chofer_vehiculo_externo" ADD CONSTRAINT "fk_revision_109" FOREIGN KEY ("coordinacion_entrega_id") REFERENCES "coordinacion_entrega" ("coordinacion_entrega_id") ON DELETE RESTRICT;

ALTER TABLE "detalle_trazabilidad" ADD CONSTRAINT "fk_revision_110" FOREIGN KEY ("carga_id") REFERENCES "carga" ("carga_id") ON DELETE RESTRICT;

ALTER TABLE "detalle_trazabilidad" ADD CONSTRAINT "fk_revision_111" FOREIGN KEY ("guia_remision_id") REFERENCES "guia_remision" ("guia_remision_id") ON DELETE RESTRICT;

ALTER TABLE "empresa_transporte_externo" ADD CONSTRAINT "fk_revision_112" FOREIGN KEY ("persona_id") REFERENCES "persona" ("persona_id") ON DELETE RESTRICT;

ALTER TABLE "entrevista_extencion" ADD CONSTRAINT "fk_revision_113" FOREIGN KEY ("fruta_derivada_id") REFERENCES "fruta_derivada" ("fruta_derivada_id") ON DELETE RESTRICT;

ALTER TABLE "entrevista_extencion" ADD CONSTRAINT "fk_revision_114" FOREIGN KEY ("registrado_por_usuario_id") REFERENCES "usuario" ("usuario_id") ON DELETE RESTRICT;

ALTER TABLE "examen_proveedor" ADD CONSTRAINT "fk_revision_115" FOREIGN KEY ("cxp_id") REFERENCES "campania_x_proveedores" ("cxp_id") ON DELETE RESTRICT;

ALTER TABLE "examen_proveedor" ADD CONSTRAINT "fk_revision_116" FOREIGN KEY ("finca_id") REFERENCES "finca" ("finca_id") ON DELETE RESTRICT;

ALTER TABLE "finca" ADD CONSTRAINT "fk_revision_117" FOREIGN KEY ("fruta_derivada_id") REFERENCES "fruta_derivada" ("fruta_derivada_id") ON DELETE RESTRICT;

ALTER TABLE "trazabilidad_transporte" ADD CONSTRAINT "fk_revision_118" FOREIGN KEY ("coordinacion_entrega_id") REFERENCES "coordinacion_entrega" ("coordinacion_entrega_id") ON DELETE RESTRICT;

ALTER TABLE "trazabilidad_transporte" ADD CONSTRAINT "fk_revision_119" FOREIGN KEY ("carga_id") REFERENCES "carga" ("carga_id") ON DELETE RESTRICT;

ALTER TABLE "origen_entrega" ADD CONSTRAINT "fk_revision_120" FOREIGN KEY ("finca_id") REFERENCES "finca" ("finca_id") ON DELETE RESTRICT;

ALTER TABLE "origen_carga" ADD CONSTRAINT "fk_revision_121" FOREIGN KEY ("finca_id") REFERENCES "finca" ("finca_id") ON DELETE RESTRICT;

ALTER TABLE "analisis_calidad" ADD CONSTRAINT "fk_revision_122" FOREIGN KEY ("finca_id") REFERENCES "finca" ("finca_id") ON DELETE RESTRICT;

ALTER TABLE "medicion_mtd" ADD CONSTRAINT "fk_revision_123" FOREIGN KEY ("finca_id") REFERENCES "finca" ("finca_id") ON DELETE RESTRICT;

ALTER TABLE "liquidacion_proveedor" ADD CONSTRAINT "fk_revision_124" FOREIGN KEY ("persona_liquidacion_id") REFERENCES "persona" ("persona_id") ON DELETE RESTRICT;

CREATE UNIQUE INDEX "UQ_campana_fruta_activa" ON agro.campana USING btree (fruta_id) WHERE (estado <> 'terminado'::campana_estado_enum);

CREATE INDEX "IDX_certificado_proveedor_documento_archivo" ON agro.certificado_proveedor USING btree (documento_archivo_id);

CREATE INDEX "IDX_chofer_empresa_transporte" ON agro.chofer_transporte_externo USING btree (id_empresa_transporte_externo);

CREATE INDEX "IDX_asignacion_chofer" ON agro.chofer_vehiculo_externo USING btree (id_chofer_transporte_externo);

CREATE INDEX "IDX_asignacion_trazabilidad" ON agro.chofer_vehiculo_externo USING btree (id_trazabilidad_transporte);

CREATE INDEX "IDX_asignacion_vehiculo" ON agro.chofer_vehiculo_externo USING btree (id_vehiculo_externo);

CREATE INDEX "IDX_detalle_trazabilidad" ON agro.detalle_trazabilidad USING btree (id_trazabilidad_transporte);

CREATE INDEX "IDX_entrevista_extencion_cxp" ON agro.entrevista_extencion USING btree (cam_x_prov_id);

CREATE INDEX "IDX_entrevista_extencion_finca" ON agro.entrevista_extencion USING btree (finca_id);

CREATE UNIQUE INDEX "UQ_entrevista_extencion_codigo" ON agro.entrevista_extencion USING btree (codigo);

CREATE INDEX "IDX_finca_proveedor" ON agro.finca USING btree (proveedor_id);

CREATE UNIQUE INDEX "UQ_proveedor_fruta" ON agro.proveedor_x_fruta USING btree (proveedor_id, fruta_id);

CREATE INDEX "IDX_trazabilidad_cxp" ON agro.trazabilidad_transporte USING btree (cxp_id);

CREATE INDEX "IDX_vehiculo_empresa_transporte" ON agro.vehiculo_externo USING btree (id_empresa_transporte_externo);

CREATE INDEX "ix_revision_22" ON "pago_proveedor" ("liquidacion_proveedor_id");

CREATE INDEX "ix_revision_23" ON "pago_transporte" ("liquidacion_transporte_id");

CREATE INDEX "ix_revision_24" ON "cobro_venta" ("factura_venta_id");

CREATE INDEX "ix_revision_25" ON "usuario" ("persona_id");

CREATE INDEX "ix_revision_26" ON "usuario" ("rol_id");

CREATE INDEX "ix_revision_27" ON "proveedor_x_persona" ("proveedor_id");

CREATE INDEX "ix_revision_28" ON "proveedor_x_persona" ("persona_id");

CREATE INDEX "ix_revision_29" ON "proveedor_x_fruta_derivada" ("proveedor_id");

CREATE INDEX "ix_revision_30" ON "proveedor_x_fruta_derivada" ("fruta_derivada_id");

CREATE INDEX "ix_revision_31" ON "certificado_campana_x_proveedor" ("certificado_id");

CREATE INDEX "ix_revision_32" ON "certificado_campana_x_proveedor" ("campania_id");

CREATE INDEX "ix_revision_33" ON "certificado_campana_x_proveedor" ("cxp_id");

CREATE INDEX "ix_revision_34" ON "certificado_campana_x_proveedor" ("proveedor_id");

CREATE INDEX "ix_revision_35" ON "ampliacion_certificado_campana" ("certificado_id");

CREATE INDEX "ix_revision_36" ON "ampliacion_certificado_campana" ("registrado_por_usuario_id");

CREATE INDEX "ix_revision_37" ON "pago_certificado_campana" ("certificado_id");

CREATE INDEX "ix_revision_38" ON "pago_certificado_campana" ("registrado_por_usuario_id");

CREATE INDEX "ix_revision_39" ON "cliente_negocio_campana_x_fruta_derivada" ("cliente_negocio_campana_id");

CREATE INDEX "ix_revision_40" ON "cliente_negocio_campana_x_fruta_derivada" ("fruta_derivada_id");

CREATE INDEX "ix_revision_41" ON "contrato_venta" ("cliente_negocio_campana_id");

CREATE INDEX "ix_revision_42" ON "entrega_programada" ("contrato_venta_id");

CREATE INDEX "ix_revision_43" ON "entrega_x_fruta_derivada" ("entrega_programada_id");

CREATE INDEX "ix_revision_44" ON "entrega_x_fruta_derivada" ("fruta_derivada_id");

CREATE INDEX "ix_revision_45" ON "solicitud_transporte" ("campania_id");

CREATE INDEX "ix_revision_46" ON "invitacion_transporte" ("solicitud_transporte_id");

CREATE INDEX "ix_revision_47" ON "invitacion_transporte" ("id_empresa_transporte_externo");

CREATE INDEX "ix_revision_48" ON "cotizacion_transporte" ("invitacion_transporte_id");

CREATE INDEX "ix_revision_49" ON "acuerdo_transporte" ("campania_id");

CREATE INDEX "ix_revision_50" ON "acuerdo_transporte" ("id_empresa_transporte_externo");

CREATE INDEX "ix_revision_51" ON "acuerdo_transporte" ("cotizacion_transporte_id");

CREATE INDEX "ix_revision_52" ON "coordinacion_entrega" ("entrega_programada_id");

CREATE INDEX "ix_revision_53" ON "coordinacion_entrega" ("acuerdo_transporte_id");

CREATE INDEX "ix_revision_54" ON "coordinacion_entrega" ("id_empresa_transporte_externo");

CREATE INDEX "ix_revision_55" ON "coordinacion_entrega" ("id_chofer_transporte_externo");

CREATE INDEX "ix_revision_56" ON "origen_entrega" ("coordinacion_entrega_id");

CREATE INDEX "ix_revision_57" ON "origen_entrega" ("cxp_id");

CREATE INDEX "ix_revision_58" ON "cosecha" ("entrega_programada_id");

CREATE INDEX "ix_revision_59" ON "analisis_calidad" ("cosecha_id");

CREATE INDEX "ix_revision_60" ON "analisis_calidad" ("cxp_id");

CREATE INDEX "ix_revision_61" ON "medicion_mtd" ("cxp_id");

CREATE INDEX "ix_revision_62" ON "medicion_mtd" ("registrado_por_usuario_id");

CREATE INDEX "ix_revision_63" ON "carga" ("coordinacion_entrega_id");

CREATE INDEX "ix_revision_64" ON "proveedor_carga" ("carga_id");

CREATE INDEX "ix_revision_65" ON "proveedor_carga" ("cxp_id");

CREATE INDEX "ix_revision_66" ON "proveedor_carga" ("fruta_derivada_id");

CREATE INDEX "ix_revision_67" ON "origen_carga" ("proveedor_carga_id");

CREATE INDEX "ix_revision_68" ON "origen_carga" ("cxp_id");

CREATE INDEX "ix_revision_69" ON "gasto_carga" ("carga_id");

CREATE INDEX "ix_revision_70" ON "guia_remision" ("carga_id");

CREATE INDEX "ix_revision_71" ON "guia_remision" ("finca_partida_id");

CREATE INDEX "ix_revision_72" ON "proveedor_guia" ("guia_remision_id");

CREATE INDEX "ix_revision_73" ON "proveedor_guia" ("carga_id");

CREATE INDEX "ix_revision_74" ON "proveedor_guia" ("proveedor_carga_id");

CREATE INDEX "ix_revision_75" ON "guia_x_norma" ("guia_remision_id");

CREATE INDEX "ix_revision_76" ON "guia_x_norma" ("norma_id");

CREATE INDEX "ix_revision_77" ON "historial_chofer" ("coordinacion_entrega_id");

CREATE INDEX "ix_revision_78" ON "historial_chofer" ("carga_id");

CREATE INDEX "ix_revision_79" ON "historial_chofer" ("id_chofer_transporte_externo");

CREATE INDEX "ix_revision_80" ON "recepcion_planta" ("carga_id");

CREATE INDEX "ix_revision_81" ON "recepcion_planta" ("id_chofer_transporte_externo");

CREATE INDEX "ix_revision_82" ON "liquidacion_proveedor" ("carga_id");

CREATE INDEX "ix_revision_83" ON "liquidacion_proveedor" ("proveedor_id");

CREATE INDEX "ix_revision_84" ON "liquidacion_proveedor" ("registrado_por_usuario_id");

CREATE INDEX "ix_revision_85" ON "liquidacion_transporte" ("carga_id");

CREATE INDEX "ix_revision_86" ON "liquidacion_transporte" ("registrado_por_usuario_id");

CREATE INDEX "ix_revision_87" ON "gasto_transporte" ("carga_id");

CREATE INDEX "ix_revision_88" ON "adelanto_transporte" ("acuerdo_transporte_id");

CREATE INDEX "ix_revision_89" ON "aplicacion_adelanto" ("adelanto_transporte_id");

CREATE INDEX "ix_revision_90" ON "factura_venta" ("carga_id");

CREATE INDEX "ix_revision_91" ON "pago_proveedor" ("registrado_por_usuario_id");

CREATE INDEX "ix_revision_92" ON "pago_transporte" ("registrado_por_usuario_id");

CREATE INDEX "ix_revision_93" ON "cobro_venta" ("registrado_por_usuario_id");

CREATE INDEX "ix_revision_94" ON "certificado_campana_x_proveedor" ("certificado_id", "campania_id");

CREATE INDEX "ix_revision_95" ON "certificado_campana_x_proveedor" ("cxp_id", "campania_id", "proveedor_id");

CREATE INDEX "ix_revision_96" ON "coordinacion_entrega" ("acuerdo_transporte_id", "id_empresa_transporte_externo");

CREATE INDEX "ix_revision_97" ON "coordinacion_entrega" ("id_vehiculo_externo", "id_empresa_transporte_externo");

CREATE INDEX "ix_revision_98" ON "coordinacion_entrega" ("id_chofer_transporte_externo", "id_empresa_transporte_externo");

CREATE INDEX "ix_revision_99" ON "historial_chofer" ("carga_id", "coordinacion_entrega_id");

CREATE INDEX "ix_revision_100" ON "proveedor_guia" ("guia_remision_id", "carga_id");

CREATE INDEX "ix_revision_101" ON "proveedor_guia" ("proveedor_carga_id", "carga_id");

CREATE INDEX "ix_revision_102" ON "aplicacion_adelanto" ("liquidacion_transporte_id");

CREATE INDEX "ix_revision_103" ON "campana" ("responsable_usuario_id");

CREATE INDEX "ix_revision_104" ON "campana" ("cerrada_por_usuario_id");

CREATE INDEX "ix_revision_105" ON "certificado_campana" ("norma_id");

CREATE INDEX "ix_revision_106" ON "chofer_transporte_externo" ("persona_id");

CREATE INDEX "ix_revision_107" ON "proveedor" ("persona_id");

CREATE INDEX "ix_revision_108" ON "chofer_transporte_externo" ("usuario_id");

CREATE INDEX "ix_revision_109" ON "chofer_vehiculo_externo" ("coordinacion_entrega_id");

CREATE INDEX "ix_revision_110" ON "detalle_trazabilidad" ("carga_id");

CREATE INDEX "ix_revision_111" ON "detalle_trazabilidad" ("guia_remision_id");

CREATE INDEX "ix_revision_112" ON "empresa_transporte_externo" ("persona_id");

CREATE INDEX "ix_revision_113" ON "entrevista_extencion" ("fruta_derivada_id");

CREATE INDEX "ix_revision_114" ON "entrevista_extencion" ("registrado_por_usuario_id");

CREATE INDEX "ix_revision_115" ON "examen_proveedor" ("cxp_id");

CREATE INDEX "ix_revision_116" ON "examen_proveedor" ("finca_id");

CREATE INDEX "ix_revision_117" ON "finca" ("fruta_derivada_id");

CREATE INDEX "ix_revision_118" ON "trazabilidad_transporte" ("coordinacion_entrega_id");

CREATE INDEX "ix_revision_119" ON "trazabilidad_transporte" ("carga_id");

CREATE INDEX "ix_revision_120" ON "origen_entrega" ("finca_id");

CREATE INDEX "ix_revision_121" ON "origen_carga" ("finca_id");

CREATE INDEX "ix_revision_122" ON "analisis_calidad" ("finca_id");

CREATE INDEX "ix_revision_123" ON "medicion_mtd" ("finca_id");

CREATE INDEX "ix_revision_124" ON "liquidacion_proveedor" ("persona_liquidacion_id");

CREATE FUNCTION "validar_entrevista_extencion_productor"()
      RETURNS trigger
      LANGUAGE plpgsql SET search_path = agro, pg_temp
      AS $$
      DECLARE
        tipo_asignacion text;
        proveedor_asignacion integer;
        proveedor_finca integer;
      BEGIN
        SELECT "tipo_proveedor"::text, "proveedor_id"
        INTO tipo_asignacion, proveedor_asignacion
        FROM "campania_x_proveedores"
        WHERE "cxp_id" = NEW."cam_x_prov_id";

        IF NOT FOUND THEN
          RAISE EXCEPTION 'La asignación campaña-proveedor % no existe',
            NEW."cam_x_prov_id";
        END IF;

        IF tipo_asignacion <> 'productor' THEN
          RAISE EXCEPTION
            'Solo los productores pueden registrar entrevistas de extensión';
        END IF;

        SELECT "proveedor_id"
        INTO proveedor_finca
        FROM "finca"
        WHERE "finca_id" = NEW."finca_id";

        IF NOT FOUND THEN
          RAISE EXCEPTION 'La finca % no existe', NEW."finca_id";
        END IF;

        IF proveedor_finca <> proveedor_asignacion THEN
          RAISE EXCEPTION
            'La finca no pertenece al proveedor de la asignación';
        END IF;


        RETURN NEW;
      END;
      $$;

CREATE TRIGGER "TRG_validar_entrevista_extencion_productor"
      BEFORE INSERT OR UPDATE OF "cam_x_prov_id", "finca_id"
      ON "entrevista_extencion"
      FOR EACH ROW
      EXECUTE FUNCTION "validar_entrevista_extencion_productor"();

CREATE FUNCTION "proteger_asignacion_con_entrevistas"()
      RETURNS trigger
      LANGUAGE plpgsql SET search_path = agro, pg_temp
      AS $$
      BEGIN
        IF EXISTS (
          SELECT 1
          FROM "entrevista_extencion"
          WHERE "cam_x_prov_id" = OLD."cxp_id"
        ) THEN
          IF NEW."tipo_proveedor"::text <> 'productor' THEN
            RAISE EXCEPTION
              'Una asignación con entrevistas debe permanecer como productor';
          END IF;

          IF EXISTS (
            SELECT 1
            FROM "entrevista_extencion" entrevista
            INNER JOIN "finca" ON "finca"."finca_id" = entrevista."finca_id"
            WHERE entrevista."cam_x_prov_id" = OLD."cxp_id"
              AND "finca"."proveedor_id" <> NEW."proveedor_id"
          ) THEN
            RAISE EXCEPTION
              'El proveedor no coincide con las fincas de las entrevistas';
          END IF;

        END IF;

        RETURN NEW;
      END;
      $$;

CREATE TRIGGER "TRG_proteger_asignacion_con_entrevistas"
      BEFORE UPDATE OF "tipo_proveedor", "proveedor_id"
      ON "campania_x_proveedores"
      FOR EACH ROW
      EXECUTE FUNCTION "proteger_asignacion_con_entrevistas"();

CREATE VIEW v_saldo_proveedor AS
SELECT l.*, l.importe_compra-coalesce((SELECT sum(p.monto) FROM pago_proveedor p WHERE p.liquidacion_proveedor_id=l.liquidacion_proveedor_id),0) AS saldo
FROM liquidacion_proveedor l;

CREATE VIEW v_saldo_factura AS
SELECT f.*, f.importe_venta-coalesce((SELECT sum(c.monto) FROM cobro_venta c WHERE c.factura_venta_id=f.factura_venta_id),0) AS saldo
FROM factura_venta f;

CREATE VIEW v_saldo_transporte AS
SELECT l.*, l.flete+coalesce((SELECT sum(g.monto) FROM gasto_transporte g WHERE g.carga_id=l.carga_id AND g.incluido_en_liquidacion),0)
-coalesce((SELECT sum(p.monto) FROM pago_transporte p WHERE p.liquidacion_transporte_id=l.liquidacion_transporte_id),0)
-coalesce((SELECT sum(a.monto) FROM aplicacion_adelanto a WHERE a.liquidacion_transporte_id=l.liquidacion_transporte_id),0) AS saldo
FROM liquidacion_transporte l;

CREATE VIEW v_control_uit AS
SELECT l.persona_liquidacion_id, extract(year FROM l.fecha)::integer AS anio, sum(l.importe_compra) AS acumulado,
u.valor,u.limite_uit,u.valor*u.limite_uit-sum(l.importe_compra) AS disponible
FROM liquidacion_proveedor l LEFT JOIN parametro_uit u ON u.anio=extract(year FROM l.fecha)::integer
GROUP BY l.persona_liquidacion_id,extract(year FROM l.fecha)::integer,u.valor,u.limite_uit;

CREATE VIEW v_estado_despacho AS
SELECT DISTINCT ON (coordinacion_entrega_id) coordinacion_entrega_id,carga_id,id_chofer_transporte_externo,estado,fecha_hora
FROM historial_chofer ORDER BY coordinacion_entrega_id,fecha_hora DESC,historial_chofer_id DESC;

CREATE VIEW v_programa_semanal AS
SELECT r.campania_id,r.cliente_negocio_id,c.contrato_venta_id,e.entrega_programada_id,e.fecha,
extract(isoyear FROM e.fecha)::integer AS anio_iso,extract(week FROM e.fecha)::integer AS semana_iso,
d.fruta_derivada_id,d.kilos_programados,co.id_vehiculo_externo
FROM entrega_programada e JOIN entrega_x_fruta_derivada d ON d.entrega_programada_id=e.entrega_programada_id
JOIN contrato_venta c ON c.contrato_venta_id=e.contrato_venta_id
JOIN cliente_negocio_campana r ON r.cliente_negocio_campana_id=c.cliente_negocio_campana_id
LEFT JOIN coordinacion_entrega co ON co.entrega_programada_id=e.entrega_programada_id;

-- Protecciones funcionales acotadas: no sustituye servicios de permisos/cierre.
CREATE FUNCTION validar_recepcion_compras() RETURNS trigger
LANGUAGE plpgsql SET search_path = agro, pg_temp AS $$
DECLARE item jsonb; ids integer[] := '{}'; pid integer; total numeric := 0; completos boolean := true; cargado numeric;
BEGIN
  FOR item IN SELECT value FROM jsonb_array_elements(NEW.compras) LOOP
    IF jsonb_typeof(item) <> 'object' OR NOT item ? 'providerId' THEN
      RAISE EXCEPTION 'Cada compra requiere providerId y datos de revisión';
    END IF;
    pid := (item->>'providerId')::integer;
    IF pid IS NULL OR pid = ANY(ids) THEN RAISE EXCEPTION 'Proveedor duplicado o inválido en recepción'; END IF;
    ids := array_append(ids, pid);
    SELECT sum(pc.kilos_cargados) INTO cargado FROM proveedor_carga pc
      JOIN campania_x_proveedores p ON p.cxp_id=pc.cxp_id
      WHERE pc.carga_id=NEW.carga_id AND p.proveedor_id=pid;
    IF cargado IS NULL THEN RAISE EXCEPTION 'El proveedor no pertenece a esta carga'; END IF;
    IF item->>'recognizedQuantity' IS NULL THEN completos := false;
    ELSE
      IF (item->>'recognizedQuantity')::numeric <= 0 OR (item->>'recognizedQuantity')::numeric > cargado + 0.01 THEN
        RAISE EXCEPTION 'Kilos reconocidos fuera de los kilos cargados del proveedor';
      END IF;
      total := total + (item->>'recognizedQuantity')::numeric;
    END IF;
  END LOOP;
  IF jsonb_array_length(NEW.compras)>0 AND completos THEN
    IF NEW.peso_planta_kg IS NULL OR abs(total-NEW.peso_planta_kg)>0.01 THEN
      RAISE EXCEPTION 'La suma reconocida debe coincidir con el peso de planta';
    END IF;
    IF cardinality(ids) <> (SELECT count(DISTINCT p.proveedor_id) FROM proveedor_carga pc
      JOIN campania_x_proveedores p ON p.cxp_id=pc.cxp_id WHERE pc.carga_id=NEW.carga_id) THEN
      RAISE EXCEPTION 'Completa el desglose de todos los proveedores';
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_recepcion_compras BEFORE INSERT OR UPDATE OF compras,peso_planta_kg,carga_id
ON recepcion_planta FOR EACH ROW EXECUTE FUNCTION validar_recepcion_compras();

CREATE FUNCTION validar_persona_liquidacion() RETURNS trigger
LANGUAGE plpgsql SET search_path = agro, pg_temp AS $$
DECLARE p persona%ROWTYPE; titular boolean; reconocidos numeric; proveedores integer; precio_acuerdo numeric;
BEGIN
  SELECT * INTO STRICT p FROM persona WHERE persona_id=NEW.persona_liquidacion_id;
  SELECT (proveedor.persona_id=p.persona_id OR (proveedor.nmr_documento=p.numero_documento AND proveedor.tipo_documento::text=p.tipo_documento))
    INTO titular FROM proveedor WHERE proveedor_id=NEW.proveedor_id;
  IF NOT coalesce(titular,false) AND NOT EXISTS(SELECT 1 FROM proveedor_x_persona
    WHERE proveedor_id=NEW.proveedor_id AND persona_id=p.persona_id AND activo) THEN
    RAISE EXCEPTION 'La persona no es el proveedor principal ni una persona vinculada activa';
  END IF;
  SELECT (x->>'recognizedQuantity')::numeric INTO reconocidos FROM recepcion_planta r,
    LATERAL jsonb_array_elements(r.compras) x WHERE r.carga_id=NEW.carga_id AND (x->>'providerId')::integer=NEW.proveedor_id;
  IF reconocidos IS NULL THEN
    SELECT count(DISTINCT p.proveedor_id) INTO proveedores FROM proveedor_carga pc JOIN campania_x_proveedores p
      ON p.cxp_id=pc.cxp_id WHERE pc.carga_id=NEW.carga_id;
    IF proveedores=1 AND EXISTS(SELECT 1 FROM proveedor_carga pc JOIN campania_x_proveedores p
      ON p.cxp_id=pc.cxp_id WHERE pc.carga_id=NEW.carga_id AND p.proveedor_id=NEW.proveedor_id) THEN
      SELECT peso_planta_kg INTO reconocidos FROM recepcion_planta WHERE carga_id=NEW.carga_id;
    END IF;
  END IF;
  IF reconocidos IS NULL OR abs(reconocidos-NEW.kilos_reconocidos)>0.01 THEN RAISE EXCEPTION 'Liquida los kilos reconocidos del proveedor en planta'; END IF;
  SELECT cxp.precio_compra_kg INTO precio_acuerdo FROM campania_x_proveedores cxp
    JOIN coordinacion_entrega co ON co.coordinacion_entrega_id=(SELECT coordinacion_entrega_id FROM carga WHERE carga_id=NEW.carga_id)
    JOIN entrega_programada e ON e.entrega_programada_id=co.entrega_programada_id
    JOIN contrato_venta cv ON cv.contrato_venta_id=e.contrato_venta_id
    JOIN cliente_negocio_campana cc ON cc.cliente_negocio_campana_id=cv.cliente_negocio_campana_id
    WHERE cxp.campania_id=cc.campania_id AND cxp.proveedor_id=NEW.proveedor_id;
  IF precio_acuerdo IS NULL OR precio_acuerdo IS DISTINCT FROM NEW.precio_kg_aplicado THEN RAISE EXCEPTION 'Completa el precio de compra de la participación antes de liquidar'; END IF;
  IF TG_OP='INSERT' THEN
    NEW.persona_snapshot := jsonb_build_object('nombres',p.nombres,'apellidos',p.apellidos,'tipoDocumento',p.tipo_documento,'dni',p.numero_documento);
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_persona_liquidacion BEFORE INSERT OR UPDATE OF persona_liquidacion_id,proveedor_id,carga_id,kilos_reconocidos,precio_kg_aplicado
ON liquidacion_proveedor FOR EACH ROW EXECUTE FUNCTION validar_persona_liquidacion();

CREATE FUNCTION proteger_documento_financiero() RETURNS trigger
LANGUAGE plpgsql SET search_path = agro, pg_temp AS $$
DECLARE tiene_movimientos boolean; recibido numeric; facturado numeric; precio_contrato numeric; moneda_contrato text;
BEGIN
  IF TG_TABLE_NAME='factura_venta' THEN
    -- Serializa documentos de la misma carga antes de repartir los kilos recibidos.
    PERFORM 1 FROM carga WHERE carga_id=NEW.carga_id FOR UPDATE;
    SELECT cv.precio_kg,cv.moneda INTO precio_contrato,moneda_contrato FROM carga c
      JOIN coordinacion_entrega co ON co.coordinacion_entrega_id=c.coordinacion_entrega_id
      JOIN entrega_programada e ON e.entrega_programada_id=co.entrega_programada_id
      JOIN contrato_venta cv ON cv.contrato_venta_id=e.contrato_venta_id WHERE c.carga_id=NEW.carga_id;
    IF TG_OP='INSERT' AND (precio_contrato IS NULL OR precio_contrato IS DISTINCT FROM NEW.precio_kg_aplicado OR moneda_contrato IS DISTINCT FROM NEW.moneda) THEN
      RAISE EXCEPTION 'Completa el precio y usa la moneda del contrato antes de facturar';
    END IF;
    SELECT peso_planta_kg INTO recibido FROM recepcion_planta WHERE carga_id=NEW.carga_id;
    SELECT coalesce(sum(kilos_facturados),0) INTO facturado FROM factura_venta WHERE carga_id=NEW.carga_id AND factura_venta_id<>NEW.factura_venta_id;
    IF recibido IS NULL OR facturado+NEW.kilos_facturados>recibido+0.01 THEN RAISE EXCEPTION 'Las facturas superan los kilos recibidos de la carga'; END IF;
    tiene_movimientos := EXISTS(SELECT 1 FROM cobro_venta WHERE factura_venta_id=NEW.factura_venta_id);
    IF TG_OP='UPDATE' AND tiene_movimientos AND
      (NEW.carga_id,NEW.kilos_facturados,NEW.precio_kg_aplicado,NEW.descuento,NEW.cargos,NEW.importe_venta,NEW.moneda)
      IS DISTINCT FROM (OLD.carga_id,OLD.kilos_facturados,OLD.precio_kg_aplicado,OLD.descuento,OLD.cargos,OLD.importe_venta,OLD.moneda) THEN RAISE EXCEPTION 'Conserva los importes y origen de la factura cobrada'; END IF;
  ELSIF TG_TABLE_NAME='liquidacion_proveedor' THEN
    tiene_movimientos := EXISTS(SELECT 1 FROM pago_proveedor WHERE liquidacion_proveedor_id=NEW.liquidacion_proveedor_id);
    IF TG_OP='UPDATE' AND tiene_movimientos AND
      (NEW.carga_id,NEW.proveedor_id,NEW.persona_liquidacion_id,NEW.persona_snapshot,NEW.kilos_reconocidos,NEW.precio_kg_aplicado,NEW.importe_compra)
      IS DISTINCT FROM (OLD.carga_id,OLD.proveedor_id,OLD.persona_liquidacion_id,OLD.persona_snapshot,OLD.kilos_reconocidos,OLD.precio_kg_aplicado,OLD.importe_compra) THEN RAISE EXCEPTION 'Conserva el documento de compra con pagos'; END IF;
  ELSE
    tiene_movimientos := EXISTS(SELECT 1 FROM pago_transporte WHERE liquidacion_transporte_id=NEW.liquidacion_transporte_id)
      OR EXISTS(SELECT 1 FROM aplicacion_adelanto WHERE liquidacion_transporte_id=NEW.liquidacion_transporte_id);
    IF TG_OP='UPDATE' AND tiene_movimientos AND (NEW.carga_id,NEW.flete) IS DISTINCT FROM (OLD.carga_id,OLD.flete) THEN RAISE EXCEPTION 'Conserva el flete liquidado con movimientos'; END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_documento_venta BEFORE INSERT OR UPDATE ON factura_venta FOR EACH ROW EXECUTE FUNCTION proteger_documento_financiero();
CREATE TRIGGER trg_documento_compra BEFORE UPDATE ON liquidacion_proveedor FOR EACH ROW EXECUTE FUNCTION proteger_documento_financiero();
CREATE TRIGGER trg_documento_transporte BEFORE UPDATE ON liquidacion_transporte FOR EACH ROW EXECUTE FUNCTION proteger_documento_financiero();

CREATE FUNCTION validar_movimiento_financiero() RETURNS trigger
LANGUAGE plpgsql SET search_path = agro, pg_temp AS $$
DECLARE limite numeric; usado numeric; credito numeric; acuerdo_adelanto integer; acuerdo_carga integer;
BEGIN
  IF TG_TABLE_NAME='pago_proveedor' THEN
    IF TG_OP='UPDATE' AND NEW.liquidacion_proveedor_id<>OLD.liquidacion_proveedor_id THEN RAISE EXCEPTION 'Conserva el documento del pago'; END IF;
    SELECT importe_compra INTO limite FROM liquidacion_proveedor WHERE liquidacion_proveedor_id=NEW.liquidacion_proveedor_id FOR UPDATE;
    SELECT coalesce(sum(monto),0) INTO usado FROM pago_proveedor WHERE liquidacion_proveedor_id=NEW.liquidacion_proveedor_id AND pago_proveedor_id<>NEW.pago_proveedor_id;
  ELSIF TG_TABLE_NAME='cobro_venta' THEN
    IF TG_OP='UPDATE' AND NEW.factura_venta_id<>OLD.factura_venta_id THEN RAISE EXCEPTION 'Conserva el documento del cobro'; END IF;
    SELECT importe_venta INTO limite FROM factura_venta WHERE factura_venta_id=NEW.factura_venta_id FOR UPDATE;
    SELECT coalesce(sum(monto),0) INTO usado FROM cobro_venta WHERE factura_venta_id=NEW.factura_venta_id AND cobro_venta_id<>NEW.cobro_venta_id;
  ELSIF TG_TABLE_NAME='pago_certificado_campana' THEN
    IF TG_OP='UPDATE' AND NEW.certificado_id<>OLD.certificado_id THEN RAISE EXCEPTION 'Conserva el certificado del pago'; END IF;
    SELECT costo INTO limite FROM certificado_campana WHERE certificado_id=NEW.certificado_id FOR UPDATE;
    SELECT coalesce(sum(monto),0) INTO usado FROM pago_certificado_campana WHERE certificado_id=NEW.certificado_id AND pago_certificado_campana_id<>NEW.pago_certificado_campana_id;
  ELSE
    IF TG_OP='UPDATE' AND NEW.liquidacion_transporte_id<>OLD.liquidacion_transporte_id THEN RAISE EXCEPTION 'Conserva la liquidación del movimiento'; END IF;
    IF TG_TABLE_NAME='aplicacion_adelanto' THEN
      IF TG_OP='UPDATE' AND NEW.adelanto_transporte_id<>OLD.adelanto_transporte_id THEN RAISE EXCEPTION 'Conserva el origen del adelanto'; END IF;
      SELECT monto,acuerdo_transporte_id INTO credito,acuerdo_adelanto FROM adelanto_transporte WHERE adelanto_transporte_id=NEW.adelanto_transporte_id FOR UPDATE;
      SELECT coalesce(sum(monto),0) INTO usado FROM aplicacion_adelanto WHERE adelanto_transporte_id=NEW.adelanto_transporte_id AND aplicacion_adelanto_id<>NEW.aplicacion_adelanto_id;
      IF credito IS NULL OR usado+NEW.monto>credito THEN RAISE EXCEPTION 'El adelanto aplicado supera el disponible'; END IF;
      SELECT co.acuerdo_transporte_id INTO acuerdo_carga FROM liquidacion_transporte l JOIN carga c ON c.carga_id=l.carga_id
        JOIN coordinacion_entrega co ON co.coordinacion_entrega_id=c.coordinacion_entrega_id WHERE l.liquidacion_transporte_id=NEW.liquidacion_transporte_id;
      IF acuerdo_carga IS DISTINCT FROM acuerdo_adelanto THEN RAISE EXCEPTION 'Adelanto de otra empresa o campaña'; END IF;
    END IF;
    SELECT flete INTO limite FROM liquidacion_transporte WHERE liquidacion_transporte_id=NEW.liquidacion_transporte_id FOR UPDATE;
    limite := limite + coalesce((SELECT sum(g.monto) FROM gasto_transporte g JOIN liquidacion_transporte l ON l.carga_id=g.carga_id WHERE l.liquidacion_transporte_id=NEW.liquidacion_transporte_id AND g.incluido_en_liquidacion),0);
    IF TG_TABLE_NAME='pago_transporte' THEN
      SELECT coalesce(sum(monto),0) INTO usado FROM pago_transporte WHERE liquidacion_transporte_id=NEW.liquidacion_transporte_id AND pago_transporte_id<>NEW.pago_transporte_id;
      usado := usado + coalesce((SELECT sum(monto) FROM aplicacion_adelanto WHERE liquidacion_transporte_id=NEW.liquidacion_transporte_id),0);
    ELSE
      SELECT coalesce(sum(monto),0) INTO usado FROM aplicacion_adelanto WHERE liquidacion_transporte_id=NEW.liquidacion_transporte_id AND aplicacion_adelanto_id<>NEW.aplicacion_adelanto_id;
      usado := usado + coalesce((SELECT sum(monto) FROM pago_transporte WHERE liquidacion_transporte_id=NEW.liquidacion_transporte_id),0);
    END IF;
  END IF;
  IF limite IS NULL OR usado+NEW.monto>limite THEN RAISE EXCEPTION 'El movimiento supera el saldo del documento'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_pago_proveedor BEFORE INSERT OR UPDATE ON pago_proveedor FOR EACH ROW EXECUTE FUNCTION validar_movimiento_financiero();
CREATE TRIGGER trg_pago_transporte BEFORE INSERT OR UPDATE ON pago_transporte FOR EACH ROW EXECUTE FUNCTION validar_movimiento_financiero();
CREATE TRIGGER trg_cobro_venta BEFORE INSERT OR UPDATE ON cobro_venta FOR EACH ROW EXECUTE FUNCTION validar_movimiento_financiero();
CREATE TRIGGER trg_pago_certificado BEFORE INSERT OR UPDATE ON pago_certificado_campana FOR EACH ROW EXECUTE FUNCTION validar_movimiento_financiero();
CREATE TRIGGER trg_aplicacion_adelanto BEFORE INSERT OR UPDATE ON aplicacion_adelanto FOR EACH ROW EXECUTE FUNCTION validar_movimiento_financiero();

CREATE FUNCTION validar_desembolso_adelanto() RETURNS trigger
LANGUAGE plpgsql SET search_path = agro, pg_temp AS $$
DECLARE previsto numeric; usado numeric; tipo text;
BEGIN
  IF TG_OP='UPDATE' AND EXISTS(SELECT 1 FROM aplicacion_adelanto WHERE adelanto_transporte_id=OLD.adelanto_transporte_id)
    AND (NEW.monto,NEW.acuerdo_transporte_id) IS DISTINCT FROM (OLD.monto,OLD.acuerdo_transporte_id) THEN
    RAISE EXCEPTION 'Conserva el adelanto ya aplicado';
  END IF;
  SELECT adelanto_acordado,tipo_pago INTO previsto,tipo FROM acuerdo_transporte WHERE acuerdo_transporte_id=NEW.acuerdo_transporte_id FOR UPDATE;
  SELECT coalesce(sum(monto),0) INTO usado FROM adelanto_transporte WHERE acuerdo_transporte_id=NEW.acuerdo_transporte_id AND adelanto_transporte_id<>NEW.adelanto_transporte_id;
  IF tipo IS DISTINCT FROM 'CON_ADELANTO' OR usado+NEW.monto>previsto THEN RAISE EXCEPTION 'El desembolso supera el adelanto acordado'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_desembolso_adelanto BEFORE INSERT OR UPDATE ON adelanto_transporte FOR EACH ROW EXECUTE FUNCTION validar_desembolso_adelanto();

-- La vista anual conserva el parámetro aplicado al documento, no revaloriza el pasado.
CREATE OR REPLACE VIEW v_control_uit AS
SELECT l.persona_liquidacion_id, extract(year FROM l.fecha)::integer AS anio, sum(l.importe_compra) AS acumulado,
l.valor_uit_aplicado AS valor,l.limite_uit_aplicado AS limite_uit,
l.valor_uit_aplicado*l.limite_uit_aplicado-sum(l.importe_compra) AS disponible
FROM liquidacion_proveedor l GROUP BY l.persona_liquidacion_id,extract(year FROM l.fecha)::integer,l.valor_uit_aplicado,l.limite_uit_aplicado;


-- Catálogos iniciales del prototipo local (29/10/2026), sin usuarios demo ni movimientos.

-- Reejecutable en mantenimiento controlado; no sobrescribe valores existentes.

-- UIT: valores observados en código, no certificación de vigencia normativa. Revisar al habilitar otro año.

INSERT INTO rol(nombre) VALUES ('Administrador'), ('Chofer'), ('Extensionista'), ('Calidad') ON CONFLICT (nombre) DO NOTHING;

INSERT INTO norma(codigo,nombre) VALUES ('NOP','NOP'), ('RTPO','RTPO'), ('EU','EU'), ('ROC','ROC'), ('GLOBALGAP_GRASP','GLOBALG.A.P. / GRASP') ON CONFLICT (codigo) DO NOTHING;

INSERT INTO fruta(name) SELECT 'Mango' WHERE NOT EXISTS (SELECT 1 FROM fruta WHERE name='Mango');

INSERT INTO fruta_derivada(name,fruta_id) SELECT 'Mango Kent', f.fruta_id FROM fruta f WHERE f.name='Mango' AND NOT EXISTS (SELECT 1 FROM fruta_derivada d WHERE d.fruta_id=f.fruta_id AND d.name='Mango Kent');

INSERT INTO fruta_derivada(name,fruta_id) SELECT 'Mango Edward', f.fruta_id FROM fruta f WHERE f.name='Mango' AND NOT EXISTS (SELECT 1 FROM fruta_derivada d WHERE d.fruta_id=f.fruta_id AND d.name='Mango Edward');

INSERT INTO fruta_derivada(name,fruta_id) SELECT 'Mango Haden', f.fruta_id FROM fruta f WHERE f.name='Mango' AND NOT EXISTS (SELECT 1 FROM fruta_derivada d WHERE d.fruta_id=f.fruta_id AND d.name='Mango Haden');

INSERT INTO fruta_derivada(name,fruta_id) SELECT 'Mango Tommy Atkins', f.fruta_id FROM fruta f WHERE f.name='Mango' AND NOT EXISTS (SELECT 1 FROM fruta_derivada d WHERE d.fruta_id=f.fruta_id AND d.name='Mango Tommy Atkins');

INSERT INTO fruta_derivada(name,fruta_id) SELECT 'Mango Ataulfo', f.fruta_id FROM fruta f WHERE f.name='Mango' AND NOT EXISTS (SELECT 1 FROM fruta_derivada d WHERE d.fruta_id=f.fruta_id AND d.name='Mango Ataulfo');

INSERT INTO fruta(name) SELECT 'Palta' WHERE NOT EXISTS (SELECT 1 FROM fruta WHERE name='Palta');

INSERT INTO fruta_derivada(name,fruta_id) SELECT 'Palta Hass', f.fruta_id FROM fruta f WHERE f.name='Palta' AND NOT EXISTS (SELECT 1 FROM fruta_derivada d WHERE d.fruta_id=f.fruta_id AND d.name='Palta Hass');

INSERT INTO fruta_derivada(name,fruta_id) SELECT 'Palta Fuerte', f.fruta_id FROM fruta f WHERE f.name='Palta' AND NOT EXISTS (SELECT 1 FROM fruta_derivada d WHERE d.fruta_id=f.fruta_id AND d.name='Palta Fuerte');

INSERT INTO fruta_derivada(name,fruta_id) SELECT 'Palta Zutano', f.fruta_id FROM fruta f WHERE f.name='Palta' AND NOT EXISTS (SELECT 1 FROM fruta_derivada d WHERE d.fruta_id=f.fruta_id AND d.name='Palta Zutano');

INSERT INTO fruta(name) SELECT 'Arándano' WHERE NOT EXISTS (SELECT 1 FROM fruta WHERE name='Arándano');

INSERT INTO fruta_derivada(name,fruta_id) SELECT 'Biloxi', f.fruta_id FROM fruta f WHERE f.name='Arándano' AND NOT EXISTS (SELECT 1 FROM fruta_derivada d WHERE d.fruta_id=f.fruta_id AND d.name='Biloxi');

INSERT INTO fruta_derivada(name,fruta_id) SELECT 'Ventura', f.fruta_id FROM fruta f WHERE f.name='Arándano' AND NOT EXISTS (SELECT 1 FROM fruta_derivada d WHERE d.fruta_id=f.fruta_id AND d.name='Ventura');

INSERT INTO fruta_derivada(name,fruta_id) SELECT 'Emerald', f.fruta_id FROM fruta f WHERE f.name='Arándano' AND NOT EXISTS (SELECT 1 FROM fruta_derivada d WHERE d.fruta_id=f.fruta_id AND d.name='Emerald');

INSERT INTO fruta(name) SELECT 'Uva' WHERE NOT EXISTS (SELECT 1 FROM fruta WHERE name='Uva');

INSERT INTO fruta_derivada(name,fruta_id) SELECT 'Red Globe', f.fruta_id FROM fruta f WHERE f.name='Uva' AND NOT EXISTS (SELECT 1 FROM fruta_derivada d WHERE d.fruta_id=f.fruta_id AND d.name='Red Globe');

INSERT INTO fruta_derivada(name,fruta_id) SELECT 'Crimson Seedless', f.fruta_id FROM fruta f WHERE f.name='Uva' AND NOT EXISTS (SELECT 1 FROM fruta_derivada d WHERE d.fruta_id=f.fruta_id AND d.name='Crimson Seedless');

INSERT INTO fruta_derivada(name,fruta_id) SELECT 'Sugraone', f.fruta_id FROM fruta f WHERE f.name='Uva' AND NOT EXISTS (SELECT 1 FROM fruta_derivada d WHERE d.fruta_id=f.fruta_id AND d.name='Sugraone');

INSERT INTO fruta(name) SELECT 'Banano' WHERE NOT EXISTS (SELECT 1 FROM fruta WHERE name='Banano');

INSERT INTO fruta_derivada(name,fruta_id) SELECT 'Cavendish', f.fruta_id FROM fruta f WHERE f.name='Banano' AND NOT EXISTS (SELECT 1 FROM fruta_derivada d WHERE d.fruta_id=f.fruta_id AND d.name='Cavendish');

INSERT INTO fruta_derivada(name,fruta_id) SELECT 'Orgánico', f.fruta_id FROM fruta f WHERE f.name='Banano' AND NOT EXISTS (SELECT 1 FROM fruta_derivada d WHERE d.fruta_id=f.fruta_id AND d.name='Orgánico');

INSERT INTO fruta_derivada(name,fruta_id) SELECT 'Baby Banano', f.fruta_id FROM fruta f WHERE f.name='Banano' AND NOT EXISTS (SELECT 1 FROM fruta_derivada d WHERE d.fruta_id=f.fruta_id AND d.name='Baby Banano');

INSERT INTO parametro_uit(anio,valor,limite_uit,umbral_alerta) VALUES (2025,5350,75,0.90), (2026,5500,75,0.90) ON CONFLICT (anio) DO NOTHING;

-- guia_x_norma queda vacía: sus filas nacen de selecciones reales de cada guía, nunca de este seed.

-- Las reglas de transición, permisos y cierre completo requieren implementación de servicio; las protecciones financieras incluidas se prueban por separado.

-- Solo se cargan catálogos iniciales; no se importan históricos ni se calculan pagos/contratos desde URLs o pesos.

REVOKE ALL ON SCHEMA agro FROM PUBLIC;

REVOKE ALL ON ALL TABLES IN SCHEMA agro FROM PUBLIC;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA agro FROM PUBLIC;

COMMIT;
