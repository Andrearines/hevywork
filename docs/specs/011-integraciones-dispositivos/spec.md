# Spec 011 — Integraciones: dispositivos y HRV

## Contexto y objetivo
Integrar dispositivos del atleta: **báscula y caliper por Bluetooth** para
volcar peso/grasa, y **HRV** (variabilidad de frecuencia cardíaca) para
enriquecer métricas de recuperación.

Dependencias nuevas aprobadas: `flutter_blue_plus` y `health`
(constitución §2).

## Usuarios
Mismo perfil.

## Historias de usuario
- H1: Como usuario quiero conectar mi báscula/caliper y que el peso y la
  grasa entren solos en mi registro.
- H2: Como usuario quiero ver mi HRV junto a mi entrenamiento.

## Requisitos funcionales (EARS)

### Dispositivos BLE (H1)
- RF-1: EL SISTEMA expone `DeviceRepository` para escanear, emparejar y leer
  básculas y calipers compatibles por `flutter_blue_plus`.
- RF-2: EL SISTEMA muestra una tarjeta «Báscula y Caliper» con estado real de
  conexión (desconectado / escaneando / conectado + batería si el dispositivo
  la expone) y acciones conectar/desconectar.
- RF-3: CUANDO se lee una medición, EL SISTEMA la vuelca al registro diario
  `body_metrics` del día (peso → `weight_kg`, grasa → `body_fat_pct`,
  spec 006/009) y confirma al usuario.
- RF-4: EL SISTEMA gestiona los permisos de Android (BLE) e iOS (Bluetooth) y
  degrada con un mensaje si faltan.

### HRV (H2)
- RF-5: EL SISTEMA crea la tabla `health_metrics` (`user_id`, `date`,
  `hrv_ms`, `resting_hr`, timestamps) con RLS por `user_id`
  (`0012_health_metrics.sql`) y su equivalente local con `local_user_id`.
- RF-6: EL SISTEMA obtiene HRV/FC en reposo desde Apple Health / Google Fit
  con el paquete `health`; si no hay permiso o datos, permite **entrada
  manual** del valor del día.
- RF-7: EL SISTEMA muestra el HRV en el cluster de métricas de Entrenar y en
  la sección de dispositivos del Perfil (spec 008).
- RF-8: EL SISTEMA conserva la fuente (`health` / `manual`) para no pisar dato
  manual con una lectura automática vacía.

## Requisitos no funcionales
- La UI de entrenamiento nunca se bloquea por el escaneo BLE.
- Lecturas BLE y salud sin cron en primer plano; reintento en la próxima
  apertura si falla.
- Sin datos personales en logs.

## Casos límite
- Dispositivo no compatible → se informa y no se empareja.
- Sin permisos de salud → HRV manual únicamente.
- Dos mediciones el mismo día → gana la última (upsert por fecha).

## Fuera de alcance (011)
- Pulsómetros/relojes en vivo durante la serie (fatiga en tiempo real).
- Integración con Garmin/Strava u otras APIs en la nube.

## Criterios de finalización
- Tests del mapeo medición→`body_metrics` y de la precedencia de fuente HRV.
- `flutter test` + `flutter analyze` verdes.

## Decisiones arquitectónicas (Cerradas)
- BLE y salud son **fuentes de entrada**, no almacenes: los datos caen en
  `body_metrics` (peso/grasa) y `health_metrics` (HRV/FC) con RLS y `user_id`.
- El HRV manual tiene prioridad si no hay lectura automática válida del día.

## Dudas abiertas
- Perfiles BLE concretos a soportar (básculas estándar vs. fabricante).
