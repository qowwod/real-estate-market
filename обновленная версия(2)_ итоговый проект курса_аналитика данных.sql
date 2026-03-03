-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH 
limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)),
-- Категоризируем данные        
categorized_data as (
    select
        a.id AS advertisement_id,
        f.city_id,
        f.total_area,
        f.rooms,
        f.ceiling_height,
        f.floor,
        f.balcony,
        a.days_exposition,
        a.last_price,
        c.city,
        t.type,
 --Категоризация по региону
        case 
        	when c.city = 'Санкт-Петербург' then 'Санкт-Петербург'
        	else 'ЛенОбл'
        end as region, 
--Категоризация по активности объявления
        case 
	        when a.days_exposition is null then 'не продан' -- Апдейт после проверки: добавляем не проданные объекты
        	when a.days_exposition between 1 and 30 then 'месяц'
        	when a.days_exposition between 31 and 90 then 'квартал'
        	when a.days_exposition between 91 and 180 then 'полгода'
        	else 'больше полугода'
        end as ad_activity,
--Считаем стоимость одного квадратного метра 
     ROUND((a.last_price/f.total_area)::numeric, 2) as aprtm_price 
     from real_estate.city as c
     left join real_estate.flats as f using(city_id)
     left join real_estate.advertisement as a using(id)
     left join real_estate.type as t using(type_id)
     where t.type = 'город' and f.id IN (SELECT id FROM filtered_id)) -- Апдейт после проверки: применяем фильтр по выбросам
     -- 1 ad hoc задача
select region,
ad_activity,
COUNT(*) as total_ads,
 --Считаем долю объявлений в разрезе каждого региона
ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(partition by region)), 2) as ad_share,
--Статистика стоимости квадратного метра
MIN(aprtm_price) as min_aprtm_price,
MAX(aprtm_price) as max_aprtm_price,
ROUND(AVG(aprtm_price)::numeric,2) as avg_aprtm_price,
ROUND(percentile_disc(0.5) within group (order by aprtm_price)::numeric, 2) as mediana_aprtm_price,
ROUND(percentile_disc(0.99) within group (order by aprtm_price)::numeric,2) as perc_aprtm_price,
--Статистика площади недвижимости
MIN(total_area) as min_total_area,
MAX(total_area) as max_total_area,
ROUND(AVG(total_area)::numeric,2) as avg_total_area,
ROUND(percentile_disc(0.5) within group (order by total_area)::numeric, 2) as mediana_total_area,
ROUND(percentile_disc(0.99) within group (order by total_area)::numeric,2) as perc_total_area,
--Статитиска по количеству комнат
MIN(rooms) as min_rooms,
MAX(rooms) as max_rooms,
ROUND(AVG(rooms)::numeric,2) as avg_rooms,
ROUND(percentile_disc(0.5) within group (order by rooms)::numeric, 2) as mediana_rooms,
ROUND(percentile_disc(0.99) within group (order by rooms)::numeric,2) as perc_rooms,
--Статистика по высоте потолков 
MIN(ceiling_height) as min_ceiling_height,
MAX(ceiling_height) as max_ceiling_height,
ROUND(AVG(ceiling_height)::numeric,2) as avg_ceiling_height,
ROUND(percentile_disc(0.5) within group (order by ceiling_height)::numeric, 2) as mediana_ceiling_height,
ROUND(percentile_disc(0.99) within group (order by ceiling_height)::numeric,2) as perc_ceiling_height,
--Статистика по количеству балконов 
MIN(balcony) as min_balcony,
MAX(balcony) as max_balcony,
ROUND(AVG(balcony)::numeric,2) as avg_balcony,
ROUND(percentile_disc(0.5) within group (order by balcony)::numeric, 2) as mediana_balcony,
ROUND(percentile_disc(0.99) within group (order by balcony)::numeric,2) as perc_balcony,
--Статистка по этажам 
MIN(floor) as min_floor,
MAX(floor) as max_floor,
ROUND(AVG(floor)::numeric,2) as avg_floor,
ROUND(percentile_disc(0.5) within group (order by floor)::numeric, 2) as mediana_floor,
ROUND(percentile_disc(0.99) within group (order by floor)::numeric,2) as perc_floor
from categorized_data
where advertisement_id in (select id from filtered_id) -- Апдейт: применяем фильтр в финальном запросе
group by region, ad_activity
order by region, ad_activity 



-- 2 ad hoc задача
WITH 
limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)), 
cte_one as (
       select first_day_exposition,
       --Рассчитываем день снятия объявления. Если запрос выдает NULL в строке, значит объявление все еще активно
       first_day_exposition + days_exposition * interval '1 day' as last_day_exposition,
       extract(month from first_day_exposition) as publication_month,
       extract(month from first_day_exposition + days_exposition * interval '1 day') as withdrawal_month,
       --Рассчитываем стоимость квадратного метра, а также среднюю площадь квартиры
       ROUND((last_price/f.total_area)::numeric, 2) as aprtm_price,
       f.total_area
       from real_estate.advertisement
       inner join real_estate.flats f using(id)
       inner join real_estate.type as t using(type_id)
       where t.type = 'город' and f.id IN (SELECT id FROM filtered_id)),--Апдейт после проверки: добавлена фильтрация 
--Считаем кол-во публикаций
cte_two as (
       select publication_month,
       COUNT(*) as published_count,
       RANK() OVER (order by COUNT(*) desc) as rank_published,
       AVG(aprtm_price) FILTER (WHERE publication_month is not null) as avg_public_aprtm_price,
       AVG(total_area) FILTER (WHERE publication_month is not null) as avg_public_total_area,
       ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER()), 2) as publication_share_percent -- Апдейт: расчет доли публикации в процентах
       from cte_one
       group by publication_month),
--Считаем кол-во снятых публикаций 
cte_three as (
       select withdrawal_month,
       COUNT(*) as sold_cnt,
       RANK() OVER(order by COUNT(*) desc) as rank_sold,
       AVG(aprtm_price) FILTER (WHERE withdrawal_month is not null) as avg_sold_aprtm_price,
       AVG(total_area) FILTER (WHERE withdrawal_month is not null) as avg_sold_total_area,
       ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER()), 2) as withdrawal_share_percent
       from cte_one
       group by withdrawal_month) 
select c_tw.publication_month,
c_tw.published_count,
c_tw.rank_published,
ROUND(c_tw.avg_public_aprtm_price::numeric, 2) as avg_price,
ROUND(c_tw.avg_public_total_area::numeric,2) as avg_area,
c_tw.publication_share_percent AS publication_percent,
c_t.withdrawal_month,
c_t.sold_cnt,
c_t.rank_sold,
ROUND(c_t.avg_sold_aprtm_price::numeric, 2) as avg_sold_price,
ROUND(c_t.avg_sold_total_area::numeric, 2) as avg_sold_area,
c_t.withdrawal_share_percent AS withdrawal_percent
from cte_two as c_tw
full outer join cte_three as c_t on c_t.withdrawal_month = c_tw.publication_month
order by coalesce(c_tw.rank_published, c_t.rank_sold);

-- 3 ad hoc задача
WITH 
limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)),  
ad_stat AS (
     SELECT 
         c.city AS city_name,
         f.id AS flat_id,
         a.days_exposition,
         a.last_price,
         f.total_area,
     --Категоризируем срок продажи жилья 
     case 
        	when a.days_exposition between 1 and 30 then 'быстро продан'
        	when a.days_exposition between 31 and 90 then 'средний срок'
        	when a.days_exposition between 91 and 180 then 'медленно продан'
        	else 'очень медленно продан'
        end as sale_speed
     from real_estate.city c
     left join real_estate.flats f using(city_id)
     left join real_estate.advertisement a using(id)
     --Учитываем ТОЛЬКО Ленинградскую область
     where c.city != 'Санкт-Петербург' and f.id in (select id from filtered_id) --Апдейт после проверки: добавлена фильтрация 
     group by sale_speed, c.city,f.id, a.days_exposition, a.last_price, f.total_area),
--Рассчитываем показатели по разным объявлениям в каждом населенном пункте области, учитывая только те населенные пункты, где кол-во объявленй превышает 50 
     --Апдейт после проверки
city_totals AS (
    SELECT 
        city_name,
        COUNT(flat_id) AS total_ads_city,
        SUM(CASE WHEN days_exposition IS NOT NULL THEN 1 ELSE 0 END) AS removed_ads_city
    FROM ad_stat
    GROUP BY city_name),
city_stat AS (
    SELECT 
        ad.city_name,
        ad.sale_speed,
        COUNT(ad.flat_id) AS total_ads,
        AVG(ad.days_exposition) AS avg_days_exposition,
        -- Рассчитываем долю снятых объявлений, используя данные из city_totals
        ct.removed_ads_city * 1.0 / ct.total_ads_city AS removed_ads_ratio,
        ROUND(AVG(ad.last_price / ad.total_area)::NUMERIC, 2) AS avg_aprtm_price,
        ROUND(AVG(ad.total_area)::NUMERIC, 2) AS avg_total_area
    FROM ad_stat ad
    JOIN city_totals ct ON ad.city_name = ct.city_name
    GROUP BY ad.city_name, ad.sale_speed, ct.removed_ads_city, ct.total_ads_city
    HAVING COUNT(ad.flat_id) > 50
),
top_stat as (
     select city_name,
     sale_speed,
     total_ads,
     ROUND(avg_days_exposition::numeric,2) as avg_days, 
     ROUND(removed_ads_ratio::numeric,2) as removed_ad_ratio,
     avg_aprtm_price,
     avg_total_area,
     --Добавляем ранк для каждой строчки, чтобы потом составить рейтинг
     RANK() OVER(order by avg_days_exposition asc) AS rank
     from city_stat)
select city_name,
    sale_speed,
    total_ads,
    avg_days,
    removed_ad_ratio,
    avg_aprtm_price,
    avg_total_area
from top_stat
--Топ-15 городов
where rank <= 15 
order by avg_days desc;     
     