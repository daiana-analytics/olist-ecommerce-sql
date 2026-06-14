# Olist (SQL) — Calidad de datos, entregas y vistas listas para BI

## Calidad de datos — ¿Se puede confiar en los datos?

**Alcance.** Todas las métricas provienen de vistas publicadas y “quality-safe” en SQL Server, por ejemplo `quality.valid_orders` y `quality.order_items_valid`, que excluyen registros inconsistentes.

---

## Qué se controló

- Separación de órdenes entre **válidas e inválidas**.
- Controles de **lógica temporal** para verificar que ningún evento ocurra antes de su requisito previo.
- Publicación de **vistas quality-safe** para que los dashboards lean únicamente datos limpios.

---

## Validación técnica

- Los conteos entre raw y clean coinciden; **no hay orphans**: no existen items, pagos o reviews sin una orden padre.
- Claves saludables: no hay duplicados en **PKs** — primary keys / claves primarias — ni en **composite keys** — claves compuestas por varias columnas — y no hay valores NULL en columnas clave.
- **Dominios** dentro de rango: estados de orden permitidos, puntajes de review entre 1 y 5, pagos no negativos.
- Las **FKs** — foreign keys / claves foráneas — están habilitadas y **trusted**.
- **Consistencia económica** entre items y pagos: las diferencias por envío, descuentos o redondeos se monitorean, pero no se tratan como errores de calidad de datos.
- **Barrido diagnóstico:** un control general de eventos anteriores a la compra detectó **166** filas. Este control es **solo diagnóstico**. Los controles formales de calidad usan las violaciones temporales **T2/T3** indicadas abajo, con un total de **1.382** órdenes excluidas.

---

## Resultados

- **Órdenes totales:** 99.441
- **Órdenes inválidas:** 1.382 — aproximadamente **1,39%**
- **Órdenes válidas y entregadas:** 95.105
- **Entregas a tiempo:** 88.595 — **late rate** = 6,85% de las órdenes entregadas
- **Principal problema temporal:** 1.359 casos donde el envío fue registrado **antes** de la aprobación, más 23 casos menores.
- **Vista reparada:** `quality.orders_repaired` deja **0** violaciones residuales de lógica temporal, garantizando timestamps consistentes en la proyección corregida.

---

## Explicación

Los datos son ampliamente confiables. Solo alrededor del **1,4%** presentó inconsistencias temporales, principalmente por eventos registrados en un orden incorrecto. Los dashboards ahora leen desde vistas **quality-safe**, por lo que los números se mantienen consistentes.

---

# Entregas, pagos y clientes — Vista operativa

## Qué se analizó

- **Delivery lead time:** promedio, **p50** = mediana, **p75** = percentil 75 y **p90** = percentil 90.
- **Late rate por mes:** porcentaje de órdenes entregadas fuera de fecha.
- **Payment mix:** participación por **monto**, no solo por cantidad de transacciones.
- **Clientes recurrentes:** clientes únicos con **2 o más órdenes**.

---

## Resultados

- **Lead time:** promedio de **12,56** días; **p50 — mediana** = 10 días; **p90** = 23 días.
- **Pico de late rate:** **febrero-marzo 2018** alcanzó entre **14% y 19%**; luego se estabilizó cerca de **~7%**.
- **Payment mix por monto:**  
  - **Tarjeta de crédito:** 78,35%  
  - **Boleto:** 17,93%  
  - **Voucher:** 2,37%  
  - **Tarjeta de débito:** 1,34%  
  - **Not defined:** ~0%
- **Repeat:** aproximadamente **3%** de los clientes compra más de una vez; **promedio de órdenes por cliente ≈ 1,03**.
- **Estados con entregas más lentas según lead time promedio:**  
  - **Roraima — RR:** ~29,8 días  
  - **Amapá — AP:** ~27,2 días  
  - **Amazonas — AM:** ~26,4 días

---

## Explicación

La mayoría de las órdenes llega a tiempo. Sin embargo, existe una cola pequeña pero problemática de órdenes muy tardías, especialmente por encima del percentil 90, que afecta la experiencia del cliente. La mayor parte de los pagos se realiza con tarjeta. El método **boleto** confirma más tarde y puede demorar el despacho. La recompra es baja, cercana al **3%**, por lo que las estrategias de retención podrían mejorar los ingresos.

---

# Capa BI — Lista para dashboards

## Qué se proporciona

Vistas limpias y preagregadas listas para herramientas de **BI** — Business Intelligence — sin necesidad de transformaciones adicionales.

Ejemplos:

- `bi.v_daily_sales`
- `bi.v_payment_mix`
- `bi.v_delivery_lead_time`
- `bi.v_late_orders`
- `bi.v_repeat_customers`
- `bi.v_state_lead_time`
- `bi.v_category_sales_monthly`
- `bi.v_kpi_summary`
- `bi.v_orders_core`
- `bi.v_order_items_enriched`
- `bi.v_payments_per_order`

---

## Explicación

El trabajo pesado ya está hecho. Los dashboards pueden conectarse a estas vistas y obtener números listos para usar, consistentes y confiables desde el inicio.

---

# Qué significan estos números — Interpretación de negocio

## Confianza y madurez del proceso

Solo alrededor del **1,4%** de las órdenes se filtra por reglas de lógica temporal. Esto apunta más a problemas de **secuenciación de eventos** — por ejemplo, sistemas registrando “carrier” antes de “approval” — que a transacciones faltantes. Las vistas **quality-safe** aíslan este ruido para que la capa de **BI** trabaje con datos limpios.

---

## Historia de entregas: mediana vs. cola

La experiencia típica es buena: la **p50 — mediana** está cerca de **10 días**. El problema aparece en la **cola**: la **p90 — percentil 90** está cerca de **23 días** y existen algunos outliers extremos. Esa cola impacta en reclamos, carga de soporte y caída del **NPS** — Net Promoter Score. Gestionar la cola importa más que reducir apenas el promedio.

---

## Pico temporal en febrero-marzo 2018

El pico de late rate coincide con estacionalidad y posibles restricciones de capacidad. Una mayor proporción de métodos de pago no instantáneos, como **boleto**, probablemente demoró la confirmación y el despacho en comparación con métodos instantáneos.

---

## Pagos como fricción

La tarjeta representa aproximadamente el **78%** del monto, mientras que **boleto** representa cerca del **18%** y puede demorar la confirmación. Mover parte de los pagos por boleto hacia métodos instantáneos — tarjeta o **PIX**, sistema de pago instantáneo de Brasil — durante semanas pico podría reducir el riesgo de entregas tardías **sin modificar la logística**.

---

## Baja recompra

La recompra es cercana al **3%**, por lo que el marketplace se comporta como un modelo de compra “one-and-done”. Esto significa que la adquisición debería recuperar su costo en la primera orden. Mejorar la retención temprana puede aumentar el **GMV** — Gross Merchandise Value — y mejorar la eficiencia del **CAC** — Customer Acquisition Cost.

---

# Hipótesis para testear a continuación

- **H1:** Un **SLA regional** — Service Level Agreement / promesa de entrega mostrada al cliente — con alertas proactivas reduce tickets de soporte y percepción de demora.
- **H2:** Incentivos para usar métodos de pago instantáneos durante períodos pico reducen el late rate en aproximadamente **1 a 2 puntos porcentuales — pp**.
- **H3:** Journeys post-entrega con comunicaciones en **D+7, D+14 y D+30** pueden elevar la recompra de **~3% a ~6%**.

---

# Recomendaciones de negocio — 90 días

## 1. SLA regional y gestión de expectativas

- Mostrar un **ETA** — Estimated Time of Arrival / fecha estimada de llegada — realista por estado.
- Usar ventanas de entrega más amplias para estados con mayor demora, como **Roraima — RR**, **Amapá — AP** y **Amazonas — AM**.
- Activar **alertas proactivas** cuando el **late_rate** semanal supere el **10%** durante **2 semanas consecutivas**.
- Marcar como **crítico** cuando el late_rate supere el **15%**.

**Owner:** Customer Experience — CX / Product  
**KPIs:** late_rate, Net Promoter Score — NPS, tickets de soporte

---

## 2. Mover pagos hacia métodos instantáneos durante semanas pico

- Promover tarjeta de crédito y métodos instantáneos como **PIX** o **BNPL** — Buy Now, Pay Later — con pequeños incentivos.
- Enviar recordatorios antes del vencimiento del **boleto**.
- **Target:** aumentar entre **5 y 10 pp** la participación de pagos instantáneos en meses pico.
- **Impacto esperado:** reducción de **1 a 2 pp** en late_rate.

**Owner:** Payments / Product  
**KPIs:** participación de pagos instantáneos, tiempo de aprobación de pago, late_rate

---

## 3. Journeys de retención post-entrega

- Enviar comunicaciones en **D+7, D+14 y D+30**.
- Usar cross-sell basado en categoría.
- Testear cupones para segunda compra mediante A/B testing.
- **Target:** elevar el **repeat_rate** de aproximadamente **3% a 6%** en 90 días.
- Aumentar el **ARPU** — Average Revenue per User — entre **10% y 15%**.

**Owner:** Growth / CRM — Customer Relationship Management  
**KPIs:** repeat_rate, ARPU, tasa de conversión del journey

---

## 4. Revisión semanal de casos extremos p95+

- Revisar semanalmente las órdenes tardías ubicadas en el **p95+** — percentil 95 o superior.
- Etiquetar una causa raíz por orden: **Carrier**, **Seller**, **Address**, **Payment** o **System**.
- Asignar un owner y una fecha de resolución menor o igual a **7 días**.
- Cerrar el loop con partners logísticos o vendedores.

**Owner:** Operations — Ops  
**KPIs:** lead time p90/p95, cantidad de casos p95+ cerrados, tickets relacionados con demoras

---

## 5. Guardrail continuo de calidad de datos

- Monitorear el **invalid_ratio** — proporción de órdenes inválidas.
- Generar alerta si supera el **2% semanal**.
- Asegurar que la capa de **BI** utilice las vistas `quality.*` como fuente de verdad.

**Owner:** Data / Business Intelligence — BI  
**KPIs:** invalid_ratio, cantidad de órdenes violadas por código T2/T3

---

## Por qué estos umbrales

La línea base de **late_rate** es aproximadamente **7%**. Una alerta en **10%** detecta un deterioro relevante. Un umbral crítico de **15%** replica los picos históricos observados en febrero-marzo 2018. Estos valores pueden refinarse luego de algunas semanas de monitoreo.

---

# Glosario rápido

- **PK/FK:** Primary Key / Foreign Key — clave primaria / clave foránea.
- **Composite key:** clave compuesta por varias columnas.
- **Orphan:** fila hija sin registro padre, por ejemplo un item sin orden.
- **Domain:** conjunto o rango de valores permitidos.
- **BI:** Business Intelligence.
- **KPI:** Key Performance Indicator.
- **p50/p75/p90/p95:** percentiles; mediana, percentil 75, percentil 90 y percentil 95.
- **Late rate:** porcentaje de órdenes entregadas después de la fecha prometida.
- **NPS:** Net Promoter Score.
- **ETA:** Estimated Time of Arrival.
- **SLA:** Service Level Agreement; promesa de entrega.
- **PIX:** sistema de pago instantáneo de Brasil.
- **BNPL:** Buy Now, Pay Later.
- **GMV:** Gross Merchandise Value.
- **CAC:** Customer Acquisition Cost.
- **ARPU:** Average Revenue per User.
- **CRM:** Customer Relationship Management.
- **pp:** puntos porcentuales.

---

> **Run metadata:** SQL Server 16 · Olist público · Run date: 2025-09-10  
> **Fuentes:** `clean.*` → `quality.*` → `bi.*`




