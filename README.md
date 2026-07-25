# Eventixar (App)

App Flutter: **organizador crea y habilita un evento; vendedores, validadores y recaudadores entran por deeplink**. Gestión de **tickets** por rangos, cobros, rendición y validación. Backend: **Firestore** + auth Google.

Ver el documento de producto: [WORKFLOW.md](./WORKFLOW.md).

## Formato de tickets

- **Compartir un ticket** → imagen PNG (WhatsApp)
- **Imprimir lote** → PDF
- **Diseño** → guardado en el evento

Detalle en [WORKFLOW.md](./WORKFLOW.md).

## Correr

```bash
flutter pub get
flutter run
```

## Flujo rápido

- Login → **Continuar con Google**
- Crear evento → cotización → **Confirmar y habilitar** (pago real pendiente)
- En el evento: alta de equipo, asignar rangos, compartir links
- Colaboradores: abrir el link `/join/{token}` (sin cuenta)
