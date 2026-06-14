# Olist (SQL) — Calidad de datos, entregas y vistas listas para BI

## Calidad de datos — ¿Se puede confiar en los datos?

**Alcance.** Todas las métricas provienen de vistas publicadas “quality-safe” en SQL Server, por ejemplo `quality.valid_orders` y `quality.order_items_valid`, que excluyen registros inconsistentes.

**Qué se controló**

- Separación de órdenes entre **válidas e inválidas**.
- Controles de **lógica temporal** para verificar que ningún evento se registre antes de su requisito previo.
- Publicación de **vistas quality-safe** para que los dashboards lean únicamente datos limpios.

**Validación técnica**

- Los conteos entre raw y clean coinciden; **no hay orphans**: no existen items, pagos o reviews sin una orden padre.
- Claves saludables: no hay duplicados en **PKs** — claves primarias — ni en **composite keys** — claves compuestas por varias columnas — y no hay valores NULL en columnas clave.
- **Dominios** dentro de rango: estados de orden permitidos, puntajes de review entre 1 y 5, pagos no negativos.
- Las **FKs** — claves foráneas — están habilitadas y **trusted**.
- **Consistencia económica** entre items y pagos: las diferencias por envío, descuentos o redondeos se registran y monitorean, pero no se tratan como errores de calidad de datos.
- **Barrido diagnóstico:** un control general de eventos anteriores a la compra detectó **166** filas (**solo diagnóstico**). Los controles formales de calidad usan las violaciones de lógica temporal **T2/T3** indicadas abajo, con un total de **1.382**, para excluir órdenes.

**Resultados**

- **Órdenes totales:** 99.441
- **Órdenes inválidas:** 1.382 (≈ **1,39%**)
- **Órdenes válidas y entregadas:** 95.105
- **Entregas a tiempo:** 88.595 (**late rate** = 6,85% de las órdenes entregadas)
- **Principal problema temporal:** 1.359 casos donde el envío fue registrado **antes** de la aprobación, más 23 casos menores.
- **Vista reparada:** `quality.orders_repaired` deja **0** violaciones residuales de lógica temporal, garantizando timestamps consistentes en la proyección corregida.

**Explicación**

Los datos son ampliamente confiables. Solo alrededor del **1,4%** presentó inconsistencias temporales, principalmente por eventos registrados en un orden incorrecto. Los dashboards ahora leen desde vistas **quality-safe**, por lo que los números son consistentes.

---

## Entregas, pagos y clientes — Vista operativa

**Qué se analizó**

- **Delivery lead time**: promedio, **p50** = mediana, **p75** = percentil 75, **p90** = percentil 90, y **late rate por mes**.
- **Payment mix**: participación por **monto**, no por cantidad.
- **Clientes recurrentes**: ID único de cliente; porcentaje de compradores con **2 o más órdenes**.

**Resultados**

- **Lead time:** promedio de **12,56** días; **p50 (mediana)** = 10 días; **p90** = 23 días.
- **Pico de late rate:** **febrero-marzo 2018** alcanzó entre **14% y 19%**; luego se estabilizó cerca de **~7%**.
- **Payment mix por monto:** **tarjeta de crédito 78,35%**, **boleto 17,93%**, **voucher 2,37%**, **tarjeta de débito 1,34%**, **not defined ~0%**.
- **Repeat:** aproximadamente **3%** de los clientes compra más de una vez; **promedio de órdenes por cliente ≈ 1,03**.
- **Estados más lentos según lead time promedio:** **Roraima (RR ~29,8 d)**, **Amapá (AP ~27,2 d)**, **Amazonas (AM ~26,4 d)**.

**Explicación**

La mayoría de las órdenes llega a tiempo. Una cola pequeña pero dolorosa de órdenes muy tardías por encima del p90 afecta la experiencia. La mayoría paga con **tarjeta**; **boleto** confirma más tarde y puede demorar el despacho. **Repeat** es bajo (~3%), por lo que los programas de retención podrían aumentar los ingresos.

---

## Capa BI — Lista para dashboards

**Qué se proporciona**

Vistas limpias y preagregadas listas para herramientas de **BI** — Business Intelligence — sin necesidad de transformaciones adicionales. Ejemplos:

- `bi.v_daily_sales`
- `bi.v_payment_mix`
- `bi.v_delivery_lead_time` y `bi.v_late_orders`
- `bi.v_repeat_customers`
- `bi.v_state_lead_time`
- `bi.v_category_sales_monthly`
- `bi.v_kpi_summary` (**KPI** = Key Performance Indicator)
- **También publicadas como helpers:** `bi.v_orders_core`, `bi.v_order_items_enriched`, `bi.v_payments_per_order`

**Explicación**

El trabajo pesado ya está hecho. Los dashboards pueden conectarse a estas vistas y obtener números **listos para usar y confiables** desde el inicio.

---

## Qué significan estos números — Interpretación de negocio

- **Confianza y madurez del proceso.** Solo alrededor del **1,4%** de las órdenes se filtra por reglas de lógica temporal. Esto apunta a problemas de **secuenciación de eventos** — sistemas registrando “carrier” antes de “approval” — y no a transacciones faltantes. Las vistas **quality-safe** aíslan este ruido para que **BI** trabaje con datos limpios.

- **Historia de entregas = mediana vs. cola.** La experiencia típica es sólida: **p50 (mediana)** ≈ 10 días. El dolor está en la **cola**: **p90 (percentil 90)** ≈ 23 días y algunos outliers extremos. Esa cola genera reclamos, carga de soporte y caída del **NPS** — Net Promoter Score. Gestionar la cola importa más que reducir apenas el promedio.

- **Pico temporal (febrero-marzo 2018).** El pico de late rate coincide con estacionalidad y restricciones de capacidad. Una mayor participación de **pagos no instantáneos**, por ejemplo **boleto**, probablemente demoró la confirmación y el despacho en comparación con métodos instantáneos.

- **Pagos como fricción.** **Tarjeta** representa aproximadamente el **78%** del monto; **boleto** cerca del **18%** y demora la confirmación. Mover parte de boleto hacia **métodos instantáneos** — tarjeta o **PIX**, sistema de pago instantáneo de Brasil — durante semanas pico reduce el riesgo de entregas tardías **sin cambiar la logística**.

- **Baja recompra (~3%).** El marketplace se comporta como “one-and-done”: la adquisición debe recuperar su costo en la primera orden. Mejorar la retención temprana aumenta el **GMV** — Gross Merchandise Value — y la eficiencia del **CAC** — Customer Acquisition Cost.

**Hipótesis para testear a continuación**

H1) Un **SLA regional** — Service Level Agreement = promesa de entrega mostrada al cliente — con alertas proactivas reduce tickets de soporte y percepción de demora.

H2) Incentivos para usar métodos de pago instantáneos en períodos pico reducen el late rate en aproximadamente **1 a 2 puntos porcentuales (pp)**.

H3) **Journeys post-entrega** — nudges en D+7/14/30 días — pueden elevar la recompra de **~3% → ~6%**.

---

## Recomendaciones de negocio — 90 días

1) **SLA regional — promesa de entrega — y gestión de expectativas**

- Mostrar un **ETA** — Estimated Time of Arrival — realista por estado; usar ventanas más amplias para estados más lentos como **Roraima (RR)**, **Amapá (AP)** y **Amazonas (AM)**.
- Activar **alertas proactivas** cuando el **late_rate** semanal sea > **10%** durante **2 semanas consecutivas**; marcar como **crítico** si supera **15%**.
- *Owner:* **Customer Experience (CX)** / Product · *KPIs:* late_rate, **Net Promoter Score (NPS)**, tickets de soporte.

2) **Mover pagos hacia métodos instantáneos durante semanas pico**

- Promover **tarjeta de crédito** y métodos instantáneos, por ejemplo **PIX** — pago instantáneo de Brasil — y **BNPL** — Buy Now, Pay Later — con pequeños incentivos; enviar recordatorios antes del vencimiento del **boleto**.
- **Target:** aumento de **5 a 10 pp** en la participación de pagos instantáneos durante meses pico; **impacto esperado:** reducción de **1 a 2 pp** en late_rate.
- *Owner:* Payments / Product · *KPIs:* participación de pagos instantáneos, tiempo de aprobación del pago, late_rate.

3) **Journeys de retención post-entrega**

- Enviar nudges en **D+7/14/30 días** con cross-sell basado en categoría y A/B tests de cupón para segunda compra.
- **Target:** elevar el **repeat_rate** de **~3%** a **6%** en 90 días; aumentar el **Average Revenue per User (ARPU)** entre **10% y 15%**.
- *Owner:* Growth / **Customer Relationship Management (CRM)** · *KPIs:* repeat_rate, ARPU, tasa de conversión del journey.

4) **Revisión semanal rápida de casos extremos (p95+)**

- Revisión semanal de las órdenes tardías **top p95+** — percentil 95 o superior —; etiquetar **una causa raíz** por orden: Carrier, Seller, Address, Payment, System; asignar un owner y una fecha de vencimiento ≤ **7 días**, y cerrar loops con partners.
- *Owner:* **Operations (Ops)** · *KPIs:* lead time **p90/p95**, cantidad de casos p95+ cerrados, tickets de soporte relacionados con demoras.

5) **Guardrail continuo de calidad de datos**

- Monitorear **invalid_ratio** — proporción de órdenes inválidas — y alertar si supera el **2% semanal**; asegurar que **Business Intelligence (BI)** use las vistas `quality.*` como fuente de verdad.
- *Owner:* Data / **Business Intelligence (BI)** · *KPIs:* invalid_ratio, cantidad de órdenes con violaciones por código (T2/T3).

**¿Por qué estos umbrales?** La línea base de **late_rate ≈ 7%**. Una alerta en **10%** marca un deterioro relevante; **15%** replica los picos históricos de febrero-marzo 2018 en tus datos. Estos valores pueden refinarse después de algunas semanas de monitoreo.

---

## Glosario rápido

- **PK/FK** = Primary Key / Foreign Key — clave primaria / clave foránea
- **Composite key** = clave compuesta por varias columnas
- **Orphan** = fila hija sin su padre, por ejemplo un item sin orden
- **Domain** = conjunto o rango de valores permitidos
- **BI** = Business Intelligence
- **KPI** = Key Performance Indicator
- **p50/p75/p90/p95** = percentiles — mediana / percentil 75 / percentil 90 / percentil 95
- **Late rate** = porcentaje de órdenes entregadas después de la fecha prometida
- **NPS** = Net Promoter Score
- **ETA** = Estimated Time of Arrival
- **SLA** = Service Level Agreement — promesa de entrega
- **PIX** = sistema de pago instantáneo de Brasil
- **BNPL** = Buy Now, Pay Later
- **GMV** = Gross Merchandise Value
- **CAC** = Customer Acquisition Cost
- **ARPU** = Average Revenue per User — cliente
- **CRM** = Customer Relationship Management
- **pp** = puntos porcentuales

> **Run metadata:** SQL Server 16 · Olist público · Run date: 2025-09-10  
> Sources: `clean.*` → `quality.*` → `bi.*`


