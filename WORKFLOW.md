# Eventixar — Workflow del producto

Guía del circuito real de la app (Firestore + auth Google).  
Pendientes a propósito (no implementar todavía): **Apple Sign-In**, **pago real** (Mercado Pago / Wallet) y **ticket en URL web pública**.

---

## 1. Qué es Eventixar

App para organizar un evento con tickets numerados (beneficio, rifa, kermesse, etc.):

1. El **organizador** inicia sesión con Google, crea el evento y lo habilita.
2. Asigna **rangos de tickets** a cada vendedor (pueden ser cantidades distintas).
3. Comparte un **link de acceso** a vendedores, validadores y recaudadores.
4. El **vendedor** abre el link (sin cuenta), ve sus tickets y los comparte al comprador.
5. El **recaudador** rinde lo cobrado por cada vendedor.
6. El **validador** escanea el QR del ticket al retiro / entrada.
7. El organizador ve el resumen y puede finalizar el evento.

### Formato de los tickets

| Acción | Formato | Por qué |
|--------|--------|---------|
| **Compartir** (vendedor → comprador) | **Imagen PNG** por WhatsApp | Se ve al instante; no hay link web al comprador |
| **Imprimir lote** | **PDF** | Varias páginas / grilla en A4 |

El QR del ticket lleva payload interno `evx:{eventId}:{ticketId}` para el validador (no es un deeplink de comprador).

### Diseño del ticket

Se edita desde **Tickets → Vista previa → Editar**.  
Plantillas, colores, fondo y tipografía se **guardan en el documento del evento** (`ticketDesign`) y aplican a preview, share e impresión.

---

## 2. Roles

| Rol | ¿Necesita cuenta? | Cómo entra |
|-----|-------------------|------------|
| **Organizador** | Sí (Google) | Login → Mis eventos |
| **Vendedor** | No | Link HTTPS → app (`eventixar.web.app/join/{token}`) |
| **Validador** | No | Link HTTPS → app (`eventixar.web.app/join/{token}`) |
| **Recaudador** | No | Link HTTPS → app (`eventixar.web.app/join/{token}`) |

> El link compartido es HTTPS en **eventixar.web.app** (clicable en WhatsApp). La landing abre `eventixar://join/...`. Sin la app instalada no hay acceso. Un dominio propio (`app.eventixar.com`) puede aliasarse después si hace falta.

Los tokens viven en `tokens/{token}` + espejo owner-only `events/{id}/access/{collaboratorId}` (no en el perfil público del colaborador).

---

## 3. Organizer — flujo

### 3.1 Crear y habilitar

1. **Continuar con Google**.
2. **Crear evento**: datos → cupos de equipo → cotización.
3. **Pagar y habilitar** (hoy: *Confirmar y habilitar* provisional; genera los tickets en Firestore). El checkout real queda pendiente.
4. Entra al **workspace** del evento.

Cotización (solo por cantidad de tickets; el equipo no suma al costo):

| Tickets | Precio |
|---------|--------|
| ≤ 50 | $0 (Free) |
| ≤ 100 | $15.000 |
| ≤ 200 | $20.000 |
| ≤ 300 | $35.000 |
| > 300 | $35.000 + $80 × (tickets − 300) |

### 3.2 Workspace

| Tab | Para qué |
|-----|----------|
| **Resumen** | Totales, desempeño, finalizar evento |
| **Tickets** | Desglose, vista previa, diseño, PDF |
| **Vendedores** | Alta, rangos, share, regenerar acceso, eliminar, devoluciones al pool |
| **Validadores** | Alta, share, regenerar, eliminar |
| **Recaudadores** | Alta, share, regenerar, eliminar, detalle de rendiciones |
| **Datos** | Editar datos del evento |

### 3.3 Equipo

- **Agregar** colaborador → se crea el doc + token + se puede compartir por WhatsApp.
- **Regenerar acceso** → invalida el link anterior y emite uno nuevo (útil si cambió de celular o se filtró el link).
- **Eliminar** → borra colaborador, access y token. Si es vendedor, los tickets aún `withSeller` vuelven al **pool** (`unassigned`) para reasignar. Lo ya vendido / rendido / validado se mantiene.

### 3.4 Repartición de tickets

Por rangos `desde`–`hasta`. Un vendedor puede recibir varios rangos.  
Solo se asignan tickets `unassigned`.

**Devolver al pool** (ficha del vendedor): tickets `withSeller` seleccionados → `unassigned` (sin vendedor ni comprador). Sirve para reasignar sin borrar al vendedor.

### 3.5 Finalizar

Desde Resumen, cuando el organizador cierra el evento.

---

## 4. Portales por deeplink

### Vendedor

- Lista de sus tickets y estados.
- Marca cobros / comprador.
- Comparte **imágenes** por WhatsApp (diseño del evento).
- Imprime lote en PDF.

### Recaudador

- Elige vendedor y marca rendición de lo cobrado.

### Validador

- Escanea QR o ingresa el ticket.
- Marca entregado / validado.

La sesión de colaborador se **persiste** en el dispositivo hasta cerrar sesión o regenerar el token.

---

## 5. Estados de un ticket (ciclo)

```
unassigned → withSeller → collected → settled → delivered
                 ↑_____________|
                 (devolver al pool solo desde withSeller)
```

| Estado | Significado |
|--------|-------------|
| `unassigned` | En el pool del organizador |
| `withSeller` | Asignado al vendedor, aún no cobrado |
| `collected` | Cobrado por el vendedor |
| `settled` | Rendido al recaudador |
| `delivered` | Validado / entregado |

---

## 6. Datos (Firestore, alto nivel)

- `users/{uid}` — perfil organizador
- `events/{eventId}` — evento + `ticketDesign`
- `events/{eventId}/tickets/{ticketId}`
- `events/{eventId}/collaborators/{id}` — perfil público del rol
- `events/{eventId}/access/{id}` — token (solo owner)
- `tokens/{token}` — resolución del deeplink

Reglas: el owner autentificado administra; portales colaborador leen por token; no hay delete libre de tickets/eventos salvo lo que permita el producto.

---

## 7. Pendientes (fuera de alcance actual)

- Apple Sign-In
- Pago real del evento (MP / Wallet)
- URL web pública del ticket para el comprador

---

## 8. Correr

```bash
flutter pub get
flutter run
```

Deploy de reglas (cuando cambien):

```bash
firebase deploy --only firestore:rules
```
