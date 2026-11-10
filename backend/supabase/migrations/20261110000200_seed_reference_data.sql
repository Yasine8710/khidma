-- Reference data v1. Governorate codes are ISO 3166-2:TN. City and category
-- names (especially Arabic) must be reviewed by a native speaker before launch;
-- admins can extend categories, and cities/neighborhoods are added by migration
-- as coverage grows. City coordinates are deliberately NULL until measured.

insert into public.governorates (id, code, name_fr, name_ar, name_en) values
  (11, 'TN-11', 'Tunis',       'تونس',      'Tunis'),
  (12, 'TN-12', 'Ariana',      'أريانة',    'Ariana'),
  (13, 'TN-13', 'Ben Arous',   'بن عروس',   'Ben Arous'),
  (14, 'TN-14', 'Manouba',     'منوبة',     'Manouba'),
  (21, 'TN-21', 'Nabeul',      'نابل',      'Nabeul'),
  (22, 'TN-22', 'Zaghouan',    'زغوان',     'Zaghouan'),
  (23, 'TN-23', 'Bizerte',     'بنزرت',     'Bizerte'),
  (31, 'TN-31', 'Béja',        'باجة',      'Béja'),
  (32, 'TN-32', 'Jendouba',    'جندوبة',    'Jendouba'),
  (33, 'TN-33', 'Le Kef',      'الكاف',     'El Kef'),
  (34, 'TN-34', 'Siliana',     'سليانة',    'Siliana'),
  (41, 'TN-41', 'Kairouan',    'القيروان',  'Kairouan'),
  (42, 'TN-42', 'Kasserine',   'القصرين',   'Kasserine'),
  (43, 'TN-43', 'Sidi Bouzid', 'سيدي بوزيد', 'Sidi Bouzid'),
  (51, 'TN-51', 'Sousse',      'سوسة',      'Sousse'),
  (52, 'TN-52', 'Monastir',    'المنستير',  'Monastir'),
  (53, 'TN-53', 'Mahdia',      'المهدية',   'Mahdia'),
  (61, 'TN-61', 'Sfax',        'صفاقس',     'Sfax'),
  (71, 'TN-71', 'Gafsa',       'قفصة',      'Gafsa'),
  (72, 'TN-72', 'Tozeur',      'توزر',      'Tozeur'),
  (73, 'TN-73', 'Kébili',      'قبلي',      'Kebili'),
  (81, 'TN-81', 'Gabès',       'قابس',      'Gabès'),
  (82, 'TN-82', 'Médenine',    'مدنين',     'Medenine'),
  (83, 'TN-83', 'Tataouine',   'تطاوين',    'Tataouine');

-- Greater Tunis (initial launch area)
insert into public.cities (governorate_id, name_fr, name_ar, name_en) values
  (11, 'Tunis',           'تونس',          'Tunis'),
  (11, 'La Marsa',        'المرسى',        'La Marsa'),
  (11, 'Carthage',        'قرطاج',         'Carthage'),
  (11, 'Le Bardo',        'باردو',         'Le Bardo'),
  (11, 'Sidi Bou Saïd',   'سيدي بوسعيد',   'Sidi Bou Said'),
  (11, 'La Goulette',     'حلق الوادي',    'La Goulette'),
  (12, 'Ariana',          'أريانة',        'Ariana'),
  (12, 'Raoued',          'رواد',          'Raoued'),
  (12, 'La Soukra',       'سكرة',          'La Soukra'),
  (12, 'Ettadhamen',      'التضامن',       'Ettadhamen'),
  (12, 'Mnihla',          'المنيهلة',      'Mnihla'),
  (13, 'Ben Arous',       'بن عروس',       'Ben Arous'),
  (13, 'Radès',           'رادس',          'Radès'),
  (13, 'Hammam Lif',      'حمام الأنف',    'Hammam Lif'),
  (13, 'Mégrine',         'المقرين',       'Mégrine'),
  (13, 'Ezzahra',         'الزهراء',       'Ezzahra'),
  (13, 'Fouchana',        'فوشانة',        'Fouchana'),
  (14, 'Manouba',         'منوبة',         'Manouba'),
  (14, 'Oued Ellil',      'وادي الليل',    'Oued Ellil'),
  (14, 'Douar Hicher',    'دوار هيشر',     'Douar Hicher'),
  (14, 'Tebourba',        'تبربة',         'Tebourba');

-- A few neighborhoods to exercise the three-level hierarchy
insert into public.neighborhoods (city_id, name_fr, name_ar, name_en)
select c.id, n.name_fr, n.name_ar, n.name_en
from public.cities c
join (values
  ('La Marsa',  'Gammarth',    'قمرت',       'Gammarth'),
  ('La Marsa',  'Sidi Daoud',  'سيدي داود',  'Sidi Daoud'),
  ('Tunis',     'Lafayette',   'لافايات',    'Lafayette'),
  ('Tunis',     'El Menzah',   'المنزه',     'El Menzah'),
  ('Ariana',    'Borj Louzir', 'برج الوزير', 'Borj Louzir')
) as n (city_fr, name_fr, name_ar, name_en) on n.city_fr = c.name_fr;

insert into public.service_categories
  (slug, name_fr, name_ar, name_en, description_fr, description_ar, description_en, icon, sort_order)
values
  ('plumbing', 'Plomberie', 'السباكة', 'Plumbing',
    'Fuites, installations sanitaires, chauffe-eau.', 'تسربات، تركيبات صحية، سخانات المياه.', 'Leaks, sanitary installations, water heaters.', 'plumbing', 10),
  ('electricity', 'Électricité', 'الكهرباء', 'Electricity',
    'Installations, pannes, tableaux électriques.', 'تركيبات، أعطال، لوحات كهربائية.', 'Installations, faults, electrical panels.', 'bolt', 20),
  ('air-conditioning', 'Climatisation', 'التكييف', 'Air conditioning',
    'Installation, entretien et réparation de climatiseurs.', 'تركيب وصيانة وإصلاح المكيفات.', 'Installation, maintenance and repair of air conditioners.', 'ac_unit', 30),
  ('mechanics', 'Mécanique', 'الميكانيك', 'Mechanics',
    'Réparation et entretien de véhicules.', 'إصلاح وصيانة السيارات.', 'Vehicle repair and maintenance.', 'car_repair', 40),
  ('painting', 'Peinture', 'الدهن', 'Painting',
    'Peinture intérieure et extérieure.', 'دهن داخلي وخارجي.', 'Interior and exterior painting.', 'format_paint', 50),
  ('carpentry', 'Menuiserie', 'النجارة', 'Carpentry',
    'Meubles, portes, fenêtres en bois.', 'أثاث وأبواب ونوافذ خشبية.', 'Wooden furniture, doors and windows.', 'carpenter', 60),
  ('cleaning', 'Nettoyage', 'التنظيف', 'Cleaning',
    'Nettoyage de maisons, bureaux et fin de chantier.', 'تنظيف المنازل والمكاتب وما بعد الأشغال.', 'Home, office and post-construction cleaning.', 'cleaning_services', 70),
  ('appliance-repair', 'Réparation d''électroménager', 'إصلاح الأجهزة المنزلية', 'Appliance repair',
    'Machines à laver, réfrigérateurs, fours.', 'غسالات وثلاجات وأفران.', 'Washing machines, refrigerators, ovens.', 'kitchen', 80),
  ('construction', 'Construction', 'البناء', 'Construction',
    'Maçonnerie, carrelage, rénovation.', 'بناء، تبليط، ترميم.', 'Masonry, tiling, renovation.', 'construction', 90),
  ('gardening', 'Jardinage', 'البستنة', 'Gardening',
    'Entretien de jardins et espaces verts.', 'صيانة الحدائق والمساحات الخضراء.', 'Garden and green space maintenance.', 'yard', 100),
  ('moving', 'Déménagement', 'نقل الأثاث', 'Moving services',
    'Transport et déménagement.', 'نقل الأثاث والأمتعة.', 'Transport and moving.', 'local_shipping', 110),
  ('maintenance', 'Maintenance générale', 'الصيانة العامة', 'General maintenance',
    'Petits travaux et dépannage à domicile.', 'أعمال صغيرة وإصلاحات منزلية.', 'Small jobs and home repairs.', 'handyman', 120);
