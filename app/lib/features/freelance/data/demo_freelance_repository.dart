import '../../../core/format/search_text.dart';
import '../../marketplace/domain/marketplace_domain.dart';
import '../../portfolio/domain/portfolio_domain.dart';
import '../domain/freelance_domain.dart';

/// Made-up freelancers for development and screenshots. NOTHING here is a
/// real person, rating or verification. Shown only in debug builds or with
/// `--dart-define=DEMO_DATA=true`, and every name says "démo". The owner side
/// is not simulated: it answers "not configured".
const demoDigitalCategories = <DigitalCategory>[
  DigitalCategory(
    id: 1,
    slug: 'web-development',
    nameFr: 'Développement web',
    nameAr: 'تطوير المواقع',
    nameEn: 'Web development',
    icon: 'code',
    sortOrder: 10,
  ),
  DigitalCategory(
    id: 2,
    slug: 'mobile-development',
    nameFr: 'Développement mobile',
    nameAr: 'تطوير تطبيقات الجوال',
    nameEn: 'Mobile app development',
    icon: 'phone_iphone',
    sortOrder: 20,
  ),
  DigitalCategory(
    id: 3,
    slug: 'design',
    nameFr: 'Design graphique et UI/UX',
    nameAr: 'التصميم الغرافيكي وUI/UX',
    nameEn: 'Graphic and UI/UX design',
    icon: 'brush',
    sortOrder: 30,
  ),
  DigitalCategory(
    id: 4,
    slug: 'video-editing',
    nameFr: 'Montage vidéo',
    nameAr: 'مونتاج الفيديو',
    nameEn: 'Video editing',
    icon: 'movie',
    sortOrder: 40,
  ),
  DigitalCategory(
    id: 5,
    slug: 'marketing',
    nameFr: 'Marketing digital',
    nameAr: 'التسويق الرقمي',
    nameEn: 'Digital marketing',
    icon: 'campaign',
    sortOrder: 50,
  ),
  DigitalCategory(
    id: 6,
    slug: 'content-writing',
    nameFr: 'Rédaction et traduction',
    nameAr: 'الكتابة والترجمة',
    nameEn: 'Writing and translation',
    icon: 'edit_note',
    sortOrder: 60,
  ),
];

const _demoFreelancers = <FreelancerSummary>[
  FreelancerSummary(
    id: 'demo-f1',
    name: 'Amine (démo)',
    headline: 'Développeur web React et Node.js',
    categoryId: 1,
    bio:
        'Profil de démonstration. Sites vitrines et applications web sur '
        'mesure, du design à la mise en ligne.',
    skills: ['React', 'Node.js', 'PostgreSQL'],
    languages: ['Français', 'Arabe', 'Anglais'],
    yearsExperience: 6,
    startingPriceMillimes: 900000,
    priceUnit: PriceUnit.project,
    verification: Verification.verified,
    rating: 4.8,
    reviewCount: 2,
  ),
  FreelancerSummary(
    id: 'demo-f2',
    name: 'Salma (démo)',
    headline: 'Designer UI/UX et identité visuelle',
    categoryId: 3,
    bio:
        'Profil de démonstration. Logos, maquettes d’applications et '
        'chartes graphiques.',
    skills: ['Figma', 'Illustrator'],
    languages: ['Français', 'Arabe'],
    yearsExperience: 4,
    startingPriceMillimes: 300000,
    priceUnit: PriceUnit.project,
    availability: Availability.busy,
    verification: Verification.verified,
    rating: 5,
    reviewCount: 1,
  ),
  FreelancerSummary(
    id: 'demo-f3',
    name: 'Yassine (démo)',
    headline: 'Monteur vidéo pour réseaux sociaux',
    categoryId: 4,
    bio:
        'Profil de démonstration. Montage de reels, publicités et '
        'présentations d’entreprise.',
    skills: ['Premiere Pro', 'After Effects'],
    languages: ['Français', 'Arabe'],
    yearsExperience: 3,
    startingPriceMillimes: 40000,
    priceUnit: PriceUnit.hour,
    verification: Verification.verified,
  ),
  FreelancerSummary(
    id: 'demo-f4',
    name: 'Ines (démo)',
    headline: 'Rédactrice et traductrice FR-AR-EN',
    categoryId: 6,
    bio:
        'Profil de démonstration. Contenus de site web, fiches produit et '
        'traductions techniques.',
    skills: ['Rédaction', 'Traduction', 'SEO'],
    languages: ['Français', 'Arabe', 'Anglais'],
    yearsExperience: 8,
    startingPriceMillimes: 120000,
    priceUnit: PriceUnit.day,
    verification: Verification.verified,
    rating: 4.5,
    reviewCount: 1,
  ),
];

class DemoFreelanceRepository implements FreelanceRepository {
  const DemoFreelanceRepository();

  static const _nc = FreelanceError(FreelanceFailure.notConfigured);

  @override
  bool get isDemo => true;

  @override
  Future<List<DigitalCategory>> categories() async => demoDigitalCategories;

  @override
  Future<List<FreelancerSummary>> search(FreelanceQuery q) async {
    final text = prepareSearchText(q.text);
    final out = [
      for (final f in _demoFreelancers)
        if ((q.categoryId == null || f.categoryId == q.categoryId) &&
            (text.isEmpty ||
                prepareSearchText(
                  '${f.name} ${f.headline} ${f.skills.join(' ')}',
                ).contains(text)))
          f,
    ]..sort((a, b) => b.rating.compareTo(a.rating));
    return out.take(q.limit).toList();
  }

  @override
  Future<FreelancerSummary?> freelancer(String id) async =>
      _demoFreelancers.where((f) => f.id == id).firstOrNull;

  @override
  Future<List<FreelancePortfolioItem>> portfolio(String id) async =>
      id == 'demo-f1'
      ? const [
          FreelancePortfolioItem(
            id: 'demo-p1',
            kind: PortfolioKind.link,
            title: 'Site vitrine (démo)',
            description: 'Exemple de lien externe.',
            url: 'https://example.com/',
          ),
          FreelancePortfolioItem(
            id: 'demo-p2',
            kind: PortfolioKind.videoLink,
            title: 'Présentation (démo)',
            url: 'https://youtu.be/dQw4w9WgXcQ',
          ),
        ]
      : const [];

  @override
  Future<List<Testimonial>> testimonials(String id) async => switch (id) {
    'demo-f1' => const [
      Testimonial(
        id: 'demo-t1',
        authorName: 'Client démo',
        projectTitle: 'Site de boutique',
        rating: 5,
        body: 'Témoignage de démonstration : travail soigné et livré à temps.',
      ),
      Testimonial(
        id: 'demo-t2',
        authorName: 'Cliente démo',
        rating: 4,
        body: 'Témoignage de démonstration : bonne communication.',
      ),
    ],
    _ => const [],
  };

  @override
  Future<String> revealContact(String id) async => throw _nc;
  @override
  Future<MyFreelancer?> mine() async => throw _nc;
  @override
  Future<void> becomeFreelancer() async => throw _nc;
  @override
  Future<void> save(FreelanceInput input) async => throw _nc;
  @override
  Future<void> setPublished(bool published) async => throw _nc;
  @override
  Future<FreelancePortfolioItem> addPhoto(
    PreparedPhoto photo, {
    required String title,
    String? description,
  }) async => throw _nc;
  @override
  Future<FreelancePortfolioItem> addClip(
    PickedClip clip, {
    required String title,
    String? description,
  }) async => throw _nc;
  @override
  Future<FreelancePortfolioItem> addLink(
    PortfolioKind kind,
    String url, {
    required String title,
    String? description,
  }) async => throw _nc;
  @override
  Future<void> updateItem(
    String id, {
    required String title,
    String? description,
  }) async => throw _nc;
  @override
  Future<void> removeItem(FreelancePortfolioItem item) async => throw _nc;
  @override
  Future<List<TestimonialInvite>> invites() async => throw _nc;
  @override
  Future<String> createInvite({String? label}) async => throw _nc;
  @override
  Future<void> revokeInvite(String id) async => throw _nc;
}
