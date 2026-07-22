# Eventixar — Guía de uso y simulación (APK demo)

Este documento acompaña el **APK de demostración**.  
La app **no tiene backend real**: todo es simulado en memoria. Si cerrás la app por completo, algunos cambios pueden perderse al reiniciar (vuelve el seed de demo).

---

## 1. Qué es Eventixar (en esta demo)

Eventixar sirve para organizar un evento con cupones (ej. pollo a beneficio, rifa, kermesse):

1. Un **organizador** crea el evento y paga según cupones + cupos de equipo.
2. Asigna **rangos de cupones** a cada vendedor (pueden ser cantidades distintas).
3. Comparte un **link** a cada vendedor y a cada entregador.
4. El **vendedor** abre el link, ve sus cupones, imprime o marca cobros.
5. El **entregador** abre su link y, el día del retiro, lee el cupón y marca la entrega.
6. El organizador ve el resumen, rendiciones y reportes.

---

## 2. Los 3 roles

| Rol | ¿Necesita cuenta? | Cómo entra en la demo |
|-----|-------------------|------------------------|
| **Organizador** | Sí (login) | Botón **Entrar como organizador** |
| **Vendedor** | No | Botón **Simular deeplink vendedor** |
| **Entregador** | No | Botón **Simular deeplink entregador** |

También podés usar **Continuar con Google** o **Continuar con Apple**: en la demo hacen lo mismo que entrar como organizador.

---

## 3. Pantalla de inicio (Login)

Al abrir el APK ves:

- Título: **Eventixar** / *Cupones para tu evento*
- Texto: *Iniciá sesión para crear tu evento y gestionar cupones.*
- Botones Google / Apple (mock)
- Caja **Modo demo · accesos rápidos** con 3 opciones:

| Botón | Qué hace |
|-------|----------|
| **Entrar como organizador** | Entra a **Mis eventos** como María Organizadora |
| **Simular deeplink vendedor** | Entra al portal de **Ana Gómez** (vendedor del evento demo) |
| **Simular deeplink entregador** | Entra al portal de **Carlos Ruiz** (entregador del evento demo) |

Para volver al login: ícono de **cerrar sesión** (arriba a la derecha) o **Salir** en los portales de vendedor/entregador.

---

## 4. Datos que ya vienen cargados (seed)

Al entrar como organizador vas a ver 3 eventos de ejemplo:

### 4.1 Pollo a beneficio — **Activo**
- Producto: Pollo asado
- Precio cupón: $2000
- Cupones: 200
- Cupos: 3 vendedores · 2 entregadores
- Lugar de retiro: Sede del club, Av. San Martín 450
- **Ya tiene equipo y cupones asignados** (ideal para probar sin crear nada)

**Vendedores precargados**

| Nombre | Rango | Token / link demo |
|--------|-------|-------------------|
| Ana Gómez | 1–30 | `seller-ana-demo` |
| Diego Torres | 31–70 | `seller-diego-demo` |

**Entregador precargado**

| Nombre | Token / link demo |
|--------|-------------------|
| Carlos Ruiz | `deliverer-carlos-demo` |

Estado aproximado de cupones de Ana (1–30):
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

En cada tarjeta aparece: fecha · cantidad de cupones · vendedores · entregadores · estado (Activo / Pendiente de pago / Finalizado).

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
   - Precio cupón (ARS)
   - Cantidad de cupones (obligatorio, > 0)
   - Fecha del evento (obligatorio)
   - Retiro desde / hasta
   - Lugar de retiro
   - Notas (opcional)
3. Tocá **Continuar**.
4. Paso **Equipo**:
   - ¿Cuántos vendedores? (+ / −)
   - ¿Cuántos entregadores? (+ / −)
   - Pueden ser 0.
5. Tocá **Continuar**.
6. Paso **Cotización**:
   - Ves el monto total y el desglose (base por cupones + cupos).
7. Tocá **Ir a pagar y habilitar**.

#### Cotización (fórmula de la demo)

| Cupones | Base |
|---------|------|
| ≤ 50 | $0 (Free) |
| ≤ 100 | $15.000 |
| ≤ 200 | $20.000 |
| ≤ 300 | $35.000 |
| > 300 | $35.000 + $80 × (cupones − 300) |

Además:
- **+$2.500** por cada vendedor
- **+$2.000** por cada entregador

**Ejemplo:** 100 cupones + 2 vendedores + 1 entregador  
→ $15.000 + $5.000 + $2.000 = **$22.000**

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
| **Resumen** | Números: emitidos, asignados, sin asignar, cobrados, en poder, entregados + recaudación estimada |
| **Cupones** | Desglose por estado + botón de PDF simulado |
| **Vendedores** | Alta de vendedores, ver rangos, copiar link |
| **Entregadores** | Alta de entregadores, copiar link |
| **Rendiciones** | Cuadre por vendedor (cobrado / en poder / devuelto) |
| **Reportes** | Recaudación y desempeño por vendedor |
| **Datos del evento** | Editar nombre, producto, precio, fecha, retiro, notas |

Botón **Mis eventos** (arriba) vuelve al Home.

> La lectura QR del retiro **no** está acá. La hace el **entregador** con su link.

---

### 5.6 Asignar cupones a vendedores (repartición)

La repartición es por **rangos numéricos** (`desde` – `hasta`).  
Un vendedor puede tener **más cupones que otro**. Un vendedor puede recibir **varios rangos** a lo largo del tiempo (si quiere vender más).

#### Alta de un vendedor
1. Menú **Vendedores**.
2. Tocá **Agregar (X/Y)** (Y = cupos comprados al crear el evento).
3. Completá Nombre y Celular (WhatsApp).
4. Tocá **Crear y copiar link**.
5. El link queda en el portapapeles (en producción se mandaría por WhatsApp).

Si ya usaste todos los cupos de vendedores, el botón se deshabilita.

#### Asignar un rango
1. Tocá el vendedor en la lista.
2. Tocá **Asignar rango**.
3. Completá:
   - **Desde** (la app sugiere el próximo número libre)
   - **Hasta**
4. Tocá **Asignar**.

**Ejemplos válidos**
- Ana: `1` a `40` (40 cupones)
- Diego: `41` a `60` (20 cupones) → Diego tiene menos
- Más tarde Ana pide más → nueva asignación `61` a `90`

#### Compartir el link del vendedor
En la ficha del vendedor:
- Ves la URL tipo `https://app.eventixar.com/join/{token}`
- Tocá **Copiar deeplink**
- En la lista también hay ícono de **link** para copiar rápido

En esta demo el deeplink real se simula desde el Login con **Simular deeplink vendedor** (Ana).  
Si creás un vendedor nuevo, el token es generado; para probarlo en la misma sesión podés copiar el link, pero el acceso rápido del login sigue apuntando a Ana.

---

### 5.7 Alta y link de entregadores
1. Menú **Entregadores**.
2. Tocá **Agregar (X/Y)**.
3. Nombre + celular → **Crear y copiar link**.
4. El entregador **no** recibe cupones numerados: solo el link para leer/entregar el día del retiro.

Simulación rápida: Login → **Simular deeplink entregador** (Carlos).

---

### 5.8 Rendiciones (organizador ↔ vendedor)
1. Menú **Rendiciones**.
2. Elegí un vendedor que ya tenga cupones.
3. Podés:
   - Marcar **Todos como cobrado**
   - O cambiar estado cupón por cupón: En poder / Cobrado / Devuelto

Sirve para el cuadre de plata y cupones físicos.

---

## 6. Recorrido del VENDEDOR (simulación)

1. En Login tocá **Simular deeplink vendedor**.
2. Entrá al portal de **Ana Gómez** del evento **Pollo a beneficio**.
3. Vas a ver:
   - Rangos asignados (ej. `1–30`)
   - Botón **Imprimir** (simulado: muestra un mensaje)
   - Botón **Mi link**
   - Lista de cupones con estado
4. En cada cupón, menú ⋮:
   - **En mi poder**
   - **Marcar cobrado**
   - **Devuelto**

**Qué simular**
- Ana “vende” un cupón → **Marcar cobrado**
- Le sobró uno → **Devuelto**
- Quiere la hoja → **Imprimir**

Salí con **Salir** (arriba) para volver al login.

---

## 7. Recorrido del ENTREGADOR (simulación)

1. En Login tocá **Simular deeplink entregador**.
2. Entrá al portal de **Carlos Ruiz**.
3. Ves lugar y horario de retiro del evento.
4. Opciones:
   - **Escanear QR (simulado)** → avisa que uses el número manual
   - Campo **Número de cupón** + **Buscar**
5. Resultados típicos:
   - Si el cupón está **Cobrado** → podés **Marcar entregado**
   - Si no está cobrado → avisa que no figura como cobrado
   - Si ya estaba entregado → no se vuelve a entregar

**Números útiles para probar (seed de Ana)**
- Cupón **18** → cobrado → debería permitir entregar
- Cupón **20** → en poder del vendedor → no debería entregar sin estar cobrado
- Cupón **999** → no existe

---

## 8. Estados de un cupón (ciclo de vida)

```
Sin asignar
    ↓  (organizador asigna rango al vendedor)
En poder del vendedor
    ↓  (vendedor marca cobro)          ↘ Devuelto (vuelve / no se vendió)
Cobrado
    ↓  (entregador marca entrega en el retiro)
Entregado
```

| Estado | Quién lo pone | Significado |
|--------|---------------|-------------|
| Sin asignar | Sistema al crear evento | Todavía no se repartió |
| En poder del vendedor | Al asignar rango | El vendedor lo tiene para vender |
| Cobrado | Vendedor (o rendición) | Ya se cobró al comprador |
| Devuelto | Vendedor / rendición | No se vendió / se devolvió |
| Entregado | Entregador | Se entregó el producto en el retiro |

---

## 9. Guión sugerido para mostrar a alguien (10 minutos)

1. **Login** → explicar los 3 botones demo.
2. **Organizador** → mostrar Home con Activo / Pendiente / Pasado.
3. Abrir **Pollo a beneficio** → Resumen.
4. **Vendedores** → Ana y Diego, rangos distintos.
5. Entrar a Ana → mostrar **Copiar deeplink** y **Asignar rango** (dar más cupones).
6. **Entregadores** → Carlos + copiar link.
7. **Cerrar sesión**.
8. **Simular deeplink vendedor** → marcar un cupón como cobrado.
9. **Salir** → **Simular deeplink entregador** → buscar ese número y marcar entregado.
10. Volver como organizador → Resumen / Reportes para ver el impacto.

---

## 10. Limitaciones de esta demo (importante)

- No hay pago real ni Mercado Pago.
- No hay WhatsApp real: el “compartir” **copia el link** al portapapeles.
- No hay cámara QR real: el entregador busca por número.
- No hay PDF real de impresión: el botón **Imprimir** es simulado.
- Google / Apple login son mock.
- Los datos viven en memoria del dispositivo: reiniciar la app puede volver al seed inicial.
- Los deeplinks `https://app.eventixar.com/...` no abren una web real; en la demo se simulan con los botones del login.

---

## 11. Preguntas frecuentes

**¿Un vendedor puede tener más cupones que otro?**  
Sí. Asignás rangos distintos (ej. 1–100 vs 101–120).

**¿Qué pasa si un vendedor quiere vender más?**  
El organizador entra a su ficha y asigna **otro rango** con números libres.

**¿Se pueden repartir de a poco?**  
Sí. No hace falta asignar todos los cupones el día 1.

**¿El organizador entrega en el retiro?**  
No en este circuito. Alta el entregador, le pasa el link, y esa persona hace la lectura.

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
  repartir rangos a vendedores → copiar links
  dar de alta entregadores → copiar links
       ↓
VENDEDOR (link)          ENTREGADOR (link)
  imprimir / cobrar         leer cupón / entregar
       ↓                         ↓
ORGANIZADOR ve resumen, rendiciones y reportes
```

---

Con este APK + esta guía deberías poder **simular el circuito completo** sin backend.  
Si algo no coincide con la pantalla, priorizá lo que dice la UI: este documento describe el build de demo actual.
