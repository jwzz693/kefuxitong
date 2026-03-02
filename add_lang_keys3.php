<?php
/**
 * Add batch 3 language keys to all language files
 * Keys for: evaluate dialog, ad popup, audio message
 */

$langDir = __DIR__ . '/application/lang/';

$newKeys = [
    'cn' => [
        'rate_service_tip' => '请对我的服务进行评价，满意请打5星哦~',
        'service_attitude' => '服务态度',
        'suggestions' => '意见建议',
        'audio_message' => '音频消息',
        'hint_label' => '提示:',
        'ad_slot' => '广告位',
        'logo_display' => 'LOGO展示',
        'about_us' => '关于我们',
    ],
    'en' => [
        'rate_service_tip' => 'Please rate my service, give 5 stars if satisfied~',
        'service_attitude' => 'Service Attitude',
        'suggestions' => 'Suggestions',
        'audio_message' => 'Audio Message',
        'hint_label' => 'Hint:',
        'ad_slot' => 'Advertisement',
        'logo_display' => 'Logo Display',
        'about_us' => 'About Us',
    ],
    'tc' => [
        'rate_service_tip' => '請對我的服務進行評價，滿意請打5星哦~',
        'service_attitude' => '服務態度',
        'suggestions' => '意見建議',
        'audio_message' => '音頻消息',
        'hint_label' => '提示:',
        'ad_slot' => '廣告位',
        'logo_display' => 'LOGO展示',
        'about_us' => '關於我們',
    ],
    'vi' => [
        'rate_service_tip' => 'Vui lòng đánh giá dịch vụ của tôi, hãy cho 5 sao nếu hài lòng~',
        'service_attitude' => 'Thái độ phục vụ',
        'suggestions' => 'Góp ý',
        'audio_message' => 'Tin nhắn âm thanh',
        'hint_label' => 'Gợi ý:',
        'ad_slot' => 'Quảng cáo',
        'logo_display' => 'Hiển thị Logo',
        'about_us' => 'Về chúng tôi',
    ],
    'th' => [
        'rate_service_tip' => 'กรุณาให้คะแนนบริการของเรา ถ้าพอใจให้ 5 ดาวนะ~',
        'service_attitude' => 'ทัศนคติในการบริการ',
        'suggestions' => 'ข้อเสนอแนะ',
        'audio_message' => 'ข้อความเสียง',
        'hint_label' => 'คำแนะนำ:',
        'ad_slot' => 'โฆษณา',
        'logo_display' => 'แสดงโลโก้',
        'about_us' => 'เกี่ยวกับเรา',
    ],
    'rus' => [
        'rate_service_tip' => 'Пожалуйста, оцените мой сервис, поставьте 5 звёзд если довольны~',
        'service_attitude' => 'Качество обслуживания',
        'suggestions' => 'Предложения',
        'audio_message' => 'Аудио сообщение',
        'hint_label' => 'Подсказка:',
        'ad_slot' => 'Реклама',
        'logo_display' => 'Логотип',
        'about_us' => 'О нас',
    ],
    'id' => [
        'rate_service_tip' => 'Silakan beri rating layanan saya, beri 5 bintang jika puas~',
        'service_attitude' => 'Sikap Pelayanan',
        'suggestions' => 'Saran',
        'audio_message' => 'Pesan Audio',
        'hint_label' => 'Petunjuk:',
        'ad_slot' => 'Iklan',
        'logo_display' => 'Tampilan Logo',
        'about_us' => 'Tentang Kami',
    ],
    'jp' => [
        'rate_service_tip' => 'サービスを評価してください。満足であれば5つ星をお願いします~',
        'service_attitude' => 'サービス態度',
        'suggestions' => 'ご意見・ご提案',
        'audio_message' => '音声メッセージ',
        'hint_label' => 'ヒント:',
        'ad_slot' => '広告',
        'logo_display' => 'ロゴ表示',
        'about_us' => '私たちについて',
    ],
    'kr' => [
        'rate_service_tip' => '서비스를 평가해 주세요. 만족하시면 별 5개를 주세요~',
        'service_attitude' => '서비스 태도',
        'suggestions' => '의견 및 제안',
        'audio_message' => '음성 메시지',
        'hint_label' => '힌트:',
        'ad_slot' => '광고',
        'logo_display' => '로고 표시',
        'about_us' => '회사 소개',
    ],
    'es' => [
        'rate_service_tip' => 'Por favor, evalúe mi servicio. ¡Si está satisfecho, dé 5 estrellas!~',
        'service_attitude' => 'Actitud de servicio',
        'suggestions' => 'Sugerencias',
        'audio_message' => 'Mensaje de audio',
        'hint_label' => 'Sugerencia:',
        'ad_slot' => 'Publicidad',
        'logo_display' => 'Logo',
        'about_us' => 'Sobre nosotros',
    ],
    'fra' => [
        'rate_service_tip' => 'Veuillez évaluer mon service, 5 étoiles si satisfait~',
        'service_attitude' => 'Attitude de service',
        'suggestions' => 'Suggestions',
        'audio_message' => 'Message audio',
        'hint_label' => 'Conseil:',
        'ad_slot' => 'Publicité',
        'logo_display' => 'Affichage du logo',
        'about_us' => 'À propos de nous',
    ],
    'it' => [
        'rate_service_tip' => 'Si prega di valutare il mio servizio, 5 stelle se soddisfatti~',
        'service_attitude' => 'Atteggiamento del servizio',
        'suggestions' => 'Suggerimenti',
        'audio_message' => 'Messaggio audio',
        'hint_label' => 'Suggerimento:',
        'ad_slot' => 'Pubblicità',
        'logo_display' => 'Logo',
        'about_us' => 'Chi siamo',
    ],
    'de' => [
        'rate_service_tip' => 'Bitte bewerten Sie meinen Service, 5 Sterne wenn zufrieden~',
        'service_attitude' => 'Serviceeinstellung',
        'suggestions' => 'Vorschläge',
        'audio_message' => 'Audionachricht',
        'hint_label' => 'Hinweis:',
        'ad_slot' => 'Werbung',
        'logo_display' => 'Logo-Anzeige',
        'about_us' => 'Über uns',
    ],
    'pt' => [
        'rate_service_tip' => 'Por favor, avalie meu serviço, 5 estrelas se satisfeito~',
        'service_attitude' => 'Atitude de serviço',
        'suggestions' => 'Sugestões',
        'audio_message' => 'Mensagem de áudio',
        'hint_label' => 'Dica:',
        'ad_slot' => 'Publicidade',
        'logo_display' => 'Exibição do logo',
        'about_us' => 'Sobre nós',
    ],
    'ara' => [
        'rate_service_tip' => 'يرجى تقييم خدمتي، أعطِ 5 نجوم إذا كنت راضيًا~',
        'service_attitude' => 'موقف الخدمة',
        'suggestions' => 'اقتراحات',
        'audio_message' => 'رسالة صوتية',
        'hint_label' => ':تلميح',
        'ad_slot' => 'إعلان',
        'logo_display' => 'عرض الشعار',
        'about_us' => 'معلومات عنا',
    ],
    'dan' => [
        'rate_service_tip' => 'Bedøm venligst min service, giv 5 stjerner hvis tilfreds~',
        'service_attitude' => 'Serviceindstilling',
        'suggestions' => 'Forslag',
        'audio_message' => 'Lydbesked',
        'hint_label' => 'Tip:',
        'ad_slot' => 'Annonce',
        'logo_display' => 'Logo-visning',
        'about_us' => 'Om os',
    ],
    'el' => [
        'rate_service_tip' => 'Παρακαλώ αξιολογήστε την υπηρεσία μου, 5 αστέρια αν είστε ικανοποιημένοι~',
        'service_attitude' => 'Στάση εξυπηρέτησης',
        'suggestions' => 'Προτάσεις',
        'audio_message' => 'Ηχητικό μήνυμα',
        'hint_label' => 'Υπόδειξη:',
        'ad_slot' => 'Διαφήμιση',
        'logo_display' => 'Εμφάνιση λογότυπου',
        'about_us' => 'Σχετικά με εμάς',
    ],
    'nl' => [
        'rate_service_tip' => 'Beoordeel mijn service alstublieft, 5 sterren als u tevreden bent~',
        'service_attitude' => 'Service-instelling',
        'suggestions' => 'Suggesties',
        'audio_message' => 'Audiobericht',
        'hint_label' => 'Tip:',
        'ad_slot' => 'Advertentie',
        'logo_display' => 'Logo weergave',
        'about_us' => 'Over ons',
    ],
    'pl' => [
        'rate_service_tip' => 'Proszę ocenić moją usługę, 5 gwiazdek jeśli jesteś zadowolony~',
        'service_attitude' => 'Postawa usługowa',
        'suggestions' => 'Sugestie',
        'audio_message' => 'Wiadomość audio',
        'hint_label' => 'Wskazówka:',
        'ad_slot' => 'Reklama',
        'logo_display' => 'Wyświetlanie logo',
        'about_us' => 'O nas',
    ],
    'fin' => [
        'rate_service_tip' => 'Arvioi palveluni, 5 tähteä jos olet tyytyväinen~',
        'service_attitude' => 'Palveluasenne',
        'suggestions' => 'Ehdotukset',
        'audio_message' => 'Ääniviesti',
        'hint_label' => 'Vihje:',
        'ad_slot' => 'Mainos',
        'logo_display' => 'Logon näyttö',
        'about_us' => 'Tietoa meistä',
    ],
];

$langFiles = ['cn','en','tc','vi','th','rus','id','jp','kr','es','fra','it','de','pt','ara','dan','el','nl','pl','fin'];

foreach ($langFiles as $lang) {
    $file = $langDir . $lang . '.php';
    if (!file_exists($file)) {
        echo "SKIP: $file not found\n";
        continue;
    }
    
    $content = file_get_contents($file);
    $keys = $newKeys[$lang] ?? $newKeys['en'];
    
    // Build the new entries string
    $entries = '';
    foreach ($keys as $key => $value) {
        $escapedValue = str_replace("'", "\\'", $value);
        $entries .= "    '$key' => '$escapedValue',\n";
    }
    
    // Insert before the closing ];
    $content = str_replace("\n];\n", "\n" . $entries . "\n];\n", $content);
    // Also handle ]; at EOF without trailing newline
    if (strpos($content, $entries) === false) {
        $content = preg_replace('/\n\];\s*$/', "\n" . $entries . "\n];\n", $content);
    }
    
    file_put_contents($file, $content);
    echo "OK: $file updated\n";
}

echo "\nDone! Added " . count($newKeys['cn']) . " keys to " . count($langFiles) . " files.\n";
