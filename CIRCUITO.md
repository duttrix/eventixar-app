# Eventixar — Guía de uso y simulación (APK demo)

Este documento acompaña el **APK de demostración**.  
La app **no tiene backend real**: todo es simulado en memoria. Si cerrás la app por completo, algunos cambios pueden perderse al reiniciar (vuelve el seed de demo).

---

## 1. Qué es Eventixar (en esta demo)

Eventixar sirve para organizar un evento con tickets (ej. pollo a beneficio, rifa, kermesse):

1. Un **organizador** crea el evento y paga según tickets + cupos de equipo.
2. Asigna **rangos de tickets** a cada vendedor (pueden ser cantidades distintas).
3. Comparte un **link** a cada vendedor y a cada validador.
4. El **vendedor** abre el link, ve sus tickets, imprime o marca cobros.
5. El **validador** abre su link y lee el ticket/tarjeta: en el retiro del producto o en la entrada del evento.
6. El organizador ve el resumen y las rendiciones.

### Formato de los tickets (imagen vs PDF)

Decisión de producto:

| Acción | Formato | Por qué |
|--------|---------|---------|
| **Compartir un ticket** (vendedor → comprador, WhatsApp, etc.) | **Imagen** (PNG/JPG) | Se ve al instante en el teléfono, se reenvía fácil, no hace falta abrir un visor. Un ticket es una “tarjeta”. |
| **Imprimir lote** (varios o todos los del vendedor) | **PDF** | Varias páginas o grilla en A4, listo para imprimir o guardar. |

- Default del botón **Compartir** del ticket individual → imagen.
- Default de **Imprimir lote** → PDF.
- Un PDF individual puede existir más adelante como opción secundaria (“Descargar PDF”), no como default del share.

En esta demo ambos flujos están **simulados** (mensaje / share sheet con link); la app todavía no genera el archivo real.

### Diseño del ticket (personalización)

El diseño **no** se edita en la lista de Tickets: desde **Vista previa** tocás el ticket (chip **Editar** flotante) y abrís una **pantalla aparte**.

En esa pantalla (demo) podés probar:
- Plantillas (Clásico / Festivo / Oscuro / Institucional)
- Color principal y acento
- Fondo (sólido / gradiente / imagen ejemplo)
- Tipografía (sistema / destacada / compacta)

Los cambios son solo locales a la pantalla (no se guardan todavía). Más adelante: logo, fondo propio y diseño aplicado a todos los tickets del evento.

---

## 2. Los 3 roles

| Rol | ¿Necesita cuenta? | Cómo entra en la demo |
|-----|-------------------|------------------------|
| **Organizador** | Sí (login) | Botón **Entrar como organizador** |
| **Vendedor** | No | Botón **Simular deeplink vendedor** |
| **Validador** | No | Botón **Simular deeplink validador** |

También podés usar **Continuar con Google** o **Continuar con Apple**: en la demo hacen lo mismo que entrar como organizador.

---

## 3. Pantalla de inicio (Login)

Al abrir el APK ves:

- Título: **Eventixar** / *Tickets para tu evento*
- Texto: *Iniciá sesión para crear tu evento y gestionar tickets.*
- Botones Google / Apple (mock)
- Caja **Modo demo · accesos rápidos** con 3 opciones:

| Botón | Qué hace |
|-------|----------|
| **Entrar como organizador** | Entra a **Mis eventos** como María Organizadora |
| **Simular deeplink vendedor** | Entra al portal de **Ana Gómez** (vendedor del evento demo) |
| **Simular deeplink validador** | Entra al portal de **Carlos Ruiz** (validador del evento demo) |

Para volver al login: ícono de **cerrar sesión** (arriba a la derecha) o **Salir** en los portales de vendedor/validador.

---

## 4. Datos que ya vienen cargados (seed)

Al entrar como organizador vas a ver 3 eventos de ejemplo:

### 4.1 Pollo a beneficio — **Activo**
- Producto: Pollo asado
- Precio del ticket: $2000
- Tickets: 200
- Cupos: 3 vendedores · 2 validadores
- Lugar de retiro: Sede del club, Av. San Martín 450
- **Ya tiene equipo y tickets asignados** (ideal para probar sin crear nada)

**Vendedores precargados**

| Nombre | Rango | Token / link demo |
|--------|-------|-------------------|
| Ana Gómez | 1–30 | `seller-ana-demo` |
| Diego Torres | 31–70 | `seller-diego-demo` |

**Validador precargado**

| Nombre | Token / link demo |
|--------|-------------------|
| Carlos Ruiz | `validator-carlos-demo` |

Estado aproximado de tickets de Ana (1–30):
- 1–18 → **Cobrado**
- 19–26 → **En poder del vendedor**
- 27–30 → **Devuelto**

Diego (31–70): todos **En poder del vendedor**.

### 4.2 Rifa Anual — **Pendiente de pago**
- Todavía no está habilitado.
- Al tocarlo te lleva a la pantalla de **Pagar y habilitar**.

### 4.3 Kermesse 2025 — **Finalizado** (evento pasado)
- Aparece en la sección **Eventos pasados**.

---

## 5. Recorrido del ORGANIZADOR (paso a paso)

### 5.1 Entrar
1. Abrí el APK.
2. Tocá **Entrar como organizador**.
3. Llegás a **Mis eventos**.

### 5.2 Home — Mis eventos
Vas a ver:
- Botón grande **Crear evento nuevo**
- Sección **Activos y por pagar**
- Sección **Eventos pasados**

En cada tarjeta aparece: fecha · cantidad de tickets · vendedores · validadores · estado (Activo / Pendiente de pago / Finalizado).

Menú lateral (☰):
- Mis eventos
- Crear evento

Arriba a la derecha: cerrar sesión.

---

### 5.3 Crear un evento nuevo (simulación completa)

1. Tocá **Crear evento nuevo**.
2. Completá el paso **Datos**:
   - Nombre del evento (obligatorio)
   - Qué se vende (Locro / Empanadas / Pollo asado / Paella / Otro)
   - Precio del ticket (ARS)
   - Cantidad de tickets (obligatorio, > 0)
   - Fecha del evento (obligatorio)
   - Retiro desde / hasta
   - Lugar de retiro
   - Notas (opcional)
3. Tocá **Continuar**.
4. Paso **Equipo**:
   - ¿Cuántos vendedores? (+ / −)
   - ¿Cuántos validadores? (+ / −)
   - Pueden ser 0.
5. Tocá **Continuar**.
6. Paso **Cotización**:
   - Ves el monto total y el desglose (base por tickets).
7. Tocá **Ir a pagar y habilitar**.

#### Cotización (fórmula de la demo)

| Tickets | Precio |
|---------|--------|
| ≤ 50 | $0 (Free) |
| ≤ 100 | $15.000 |
| ≤ 200 | $20.000 |
| ≤ 300 | $35.000 |
| > 300 | $35.000 + $80 × (tickets − 300) |

**Importante:** el precio se calcula **solo por cantidad de tickets**. La cantidad de vendedores o validadores **no** suma al costo.

**Ejemplo:** 100 tickets → **$15.000** (da igual si hay 2 o 500 vendedores).

---

### 5.4 Pagar y habilitar
1. Ves el monto y (si no es gratis) datos demo: alias `eventixar.mp` / CBU ficticio.
2. Tocá:
   - **Confirmar pago (simulado)** si hay monto, o
   - **Habilitar gratis** si el total es $0.
3. Aparece el diálogo **Evento habilitado**.
4. Tocá **Ir al evento**.

Si tocás **Pagar después**, volvés a Home; el evento queda **Pendiente de pago** y al tocarlo retoma el pago.

---

### 5.5 Workspace del evento (menú lateral)

Entrá a **Pollo a beneficio** (o al evento que acabás de crear/pagar).

| Menú | Para qué sirve |
|------|----------------|
| **Resumen** | Recaudación, tickets por estado y desempeño por vendedor |
| **Tickets** | Desglose + PDF + diseño del ticket |
| **Vendedores** | Alta de vendedores, ver rangos y estados, compartir acceso |
| **Validadores** | Alta de validadores, compartir acceso |
| **Rendiciones** | Cuadre por vendedor + **Finalizar evento** (último paso) |
| **Datos del evento** | Editar nombre, producto, precio, fecha, retiro, notas |

Botón **Mis eventos** (arriba) vuelve al Home.

> La lectura QR del retiro **no** está acá. La hace el **validador** con su link.

---

### 5.6 Asignar tickets a vendedores (repartición)

La repartición es por **rangos numéricos** (`desde` – `hasta`).  
Un vendedor puede tener **más tickets que otro**. Un vendedor puede recibir **varios rangos** a lo largo del tiempo (si quiere vender más).

#### Alta de un vendedor
1. Menú **Vendedores**.
2. Tocá **Agregar (X/Y)** (Y = cupos comprados al crear el evento).
3. Completá Nombre y Celular (WhatsApp).
4. Tocá **Crear y compartir acceso**.
5. Se copia un mensaje listo para WhatsApp (el vendedor abre el link **sin registrarse**).

Si ya usaste todos los cupos de vendedores, el botón se deshabilita.

#### Asignar un rango
1. Tocá el vendedor en la lista.
2. Tocá **Asignar rango**.
3. Completá:
   - **Desde** (la app sugiere el próximo número libre)
   - **Hasta**
4. Tocá **Asignar**.

**Ejemplos válidos**
- Ana: `1` a `40` (40 tickets)
- Diego: `41` a `60` (20 tickets) → Diego tiene menos
- Más tarde Ana pide más → nueva asignación `61` a `90`

#### Ver estados de tickets (ej. Ana)
En la lista de vendedores y en la ficha del vendedor vas a ver chips de resumen, por ejemplo:
- **En poder del vendedor: 8**
- **Cobrado: 18**
- **Devuelto: 4**

Y debajo, cada ticket con color según estado (cobrado = verde, en poder = ámbar, devuelto = rojo).

#### Compartir el acceso del vendedor
En la ficha del vendedor:
- Texto claro: *abre el link sin registrarse*
- Botón **Compartir acceso (WhatsApp)** (copia mensaje + link)
- En la lista también hay ícono de compartir

En esta demo el acceso de Ana se simula desde el Login con **Simular deeplink vendedor**.
Si creás un vendedor nuevo, el token es generado; el acceso rápido del login sigue apuntando a Ana.

---

### 5.7 Alta y link de validadores
1. Menú **Validadores**.
2. Tocá **Agregar (X/Y)**.
3. Nombre + celular → **Crear y compartir acceso**.
4. El validador **no** recibe tickets numerados: solo el acceso para validar (retiro o entrada).

Simulación rápida: Login → **Simular deeplink validador** (Carlos).

---

### 5.8 Rendiciones (cierre del evento)

Es el **último paso** operativo.

1. Menú **Rendiciones**.
2. Ves una card por vendedor (asignados / cobrados / en poder / devueltos) con estado **Pendiente** o **Lista**.
3. Entrá a un vendedor para cuadrar ticket a ticket (o **Todos como cobrado**) y **Guardar rendición**. Eso **no** cierra el evento.
4. Cuando corresponda, tocá **Finalizar evento** (abajo):
   - Diálogo de confirmación contundente.
   - Si todavía hay tickets en poder, avisa y permite **Finalizar igual**.
5. El evento pasa a **Finalizado** (banner *solo consulta*). Las rendiciones quedan en lectura; el hard-lock total de toda la app queda para después (es cuestionable).

---

## 6. Recorrido del VENDEDOR (simulación)

1. En Login tocá **Simular deeplink vendedor**.
2. Entrá al portal de **Ana Gómez** del evento **Pollo a beneficio**.
3. Vas a ver:
   - Rangos asignados (ej. `1–30`)
   - Botón **Imprimir lote** (simulado → en producto real será **PDF**)
   - Lista de tickets con estado
4. En cada ticket pendiente: botón **Cobrar** a la derecha.
5. Cuando está cobrado: aparece **Compartir** (simulado → en producto real será **imagen** del ticket + share sheet nativo).

**Qué simular**
- Ana “vende” un ticket → **Cobrar**
- Quiere enviárselo al comprador → **Compartir** (imagen)
- Quiere la hoja de varios → **Imprimir lote** (PDF)

Salí con el ícono de **cerrar sesión** (arriba) para volver al login.

---

## 7. Recorrido del VALIDADOR (simulación)

1. En Login tocá **Simular deeplink validador**.
2. Entrá al portal de **Carlos Ruiz**.
3. Ves lugar y horario de retiro del evento.
4. Opciones:
   - **Escanear QR (simulado)** → avisa que uses el número manual
   - Campo **Número de ticket** + **Buscar**
5. Resultados típicos:
   - Si el ticket está **Cobrado** → podés **Marcar validado**
   - Si no está cobrado → avisa que no figura como cobrado
   - Si ya estaba validado → no se vuelve a validar

**Números útiles para probar (seed de Ana)**
- Ticket **18** → cobrado → debería permitir validar
- Ticket **20** → en poder del vendedor → no debería validar sin estar cobrado
- Ticket **999** → no existe

---

## 8. Estados de un ticket (ciclo de vida)

```
Sin asignar
    ↓  (organizador asigna rango al vendedor)
En poder del vendedor
    ↓  (vendedor marca cobro)          ↘ Devuelto (vuelve / no se vendió)
Cobrado
    ↓  (validador marca validado en retiro o entrada)
Validado
```

| Estado | Quién lo pone | Significado |
|--------|---------------|-------------|
| Sin asignar | Sistema al crear evento | Todavía no se repartió |
| En poder del vendedor | Al asignar rango | El vendedor lo tiene para vender |
| Cobrado | Vendedor (o rendición) | Ya se cobró al comprador |
| Devuelto | Vendedor / rendición | No se vendió / se devolvió |
| Validado | Validador | Ciclo cerrado: producto entregado o acceso concedido |

---

## 9. Guión sugerido para mostrar a alguien (10 minutos)

1. **Login** → explicar los 3 botones demo.
2. **Organizador** → mostrar Home con Activo / Pendiente / Pasado.
3. Abrir **Pollo a beneficio** → Resumen.
4. **Vendedores** → Ana y Diego, rangos distintos.
5. Entrar a Ana → ver chips de estado (cobrado / en poder / devuelto) y **Compartir acceso**.
6. **Validadores** → Carlos + compartir acceso.
7. **Cerrar sesión**.
8. **Simular deeplink vendedor** → marcar un ticket como cobrado.
9. **Salir** → **Simular deeplink validador** → buscar ese número y marcar validado.
10. Volver como organizador → **Resumen** para ver el impacto.

---

## 10. Limitaciones de esta demo (importante)

- No hay pago real ni Mercado Pago.
- No hay WhatsApp real: **Compartir acceso** (vendedor/validador) usa el share sheet / portapapeles.
- **Compartir ticket** individual todavía no genera la **imagen** real: hoy comparte texto + link (el formato objetivo es imagen).
- **Imprimir lote** todavía no genera el **PDF** real: el botón es simulado.
- No hay cámara QR real: el validador busca por número.
- Google / Apple login son mock.
- Los datos viven en memoria del dispositivo: reiniciar la app puede volver al seed inicial.
- Los deeplinks `https://app.eventixar.com/...` no abren una web real; en la demo se simulan con los botones del login.

---

## 11. Preguntas frecuentes

**¿Un vendedor puede tener más tickets que otro?**  
Sí. Asignás rangos distintos (ej. 1–100 vs 101–120).

**¿Qué pasa si un vendedor quiere vender más?**  
El organizador entra a su ficha y asigna **otro rango** con números libres.

**¿Se pueden repartir de a poco?**  
Sí. No hace falta asignar todos los tickets el día 1.

**¿El organizador valida en el retiro/entrada?**  
No en este circuito. Alta el validador, le pasa el acceso, y esa persona hace la lectura.

**¿Puedo crear vendedores de más?**  
No: el máximo es el que compraste al crear el evento (cupos).

**¿Rifa Anual por qué no abre el workspace?**  
Está **Pendiente de pago**. Primero confirmá el pago simulado.

---

## 12. Mapa mental rápido

```
ORGANIZADOR
  crear evento → cotizar → pagar
       ↓
  repartir rangos a vendedores → compartir acceso
  dar de alta validadores → compartir acceso
       ↓
VENDEDOR (link)          VALIDADOR (link)
  imprimir / cobrar         leer ticket / validar
       ↓                         ↓
ORGANIZADOR ve resumen y rendiciones
```

---

Con este APK + esta guía deberías poder **simular el circuito completo** sin backend.  
Si algo no coincide con la pantalla, priorizá lo que dice la UI: este documento describe el build de demo actual.
