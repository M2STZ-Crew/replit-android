/// The resident's screens in Tagalog, at CEFR B1 (the 5 November issue list,
/// 1.5): everyday Metro Manila Tagalog in short sentences, keeping the English
/// words people use anyway — app, report, location, Settings, OK.
///
/// Each key is the exact English the screen passes to `t()`; `{name}` is a
/// value filled in after, and stays as it is in both. An English line with no
/// entry here shows in English. test/tagalog_test.dart fails for any `t()`
/// call in a resident's screen that is missing from this map.
///
/// For whoever reviews it: keep it plain. A word a resident would have to
/// stop and think about is the wrong word, however correct.
const Map<String, String> kTagalog = {
  'Your session has ended. Please sign in again.':
      'Natapos na ang session mo. Mag-sign in ulit.',
  'If that email is registered, a reset link has been sent.':
      'Kung naka-register ang email na iyan, may reset link nang ipinadala.',
  'Failed to load notifications.': 'Hindi ma-load ang mga notification.',
  'Test notification sent.': 'Naipadala na ang test notification.',
  'Failed to load evacuation sites.': 'Hindi ma-load ang mga evacuation site.',
  'Failed to load incident areas.': 'Hindi ma-load ang mga area ng insidente.',
  'Failed to load your reports.': 'Hindi ma-load ang mga report mo.',
  'Could not reach the server.': 'Hindi ma-contact ang server.',
  'Your answer was not recorded.': 'Hindi naitala ang sagot mo.',
  'Could not save the language.': 'Hindi ma-save ang wika.',
  'Verification email sent.': 'Naipadala na ang verification email.',
  'Failed to load incidents.': 'Hindi ma-load ang mga insidente.',
  'Failed to load responders.': 'Hindi ma-load ang mga responder.',
  'Failed to load equipment.': 'Hindi ma-load ang mga kagamitan.',
  'Failed to load fire codes.': 'Hindi ma-load ang mga fire code.',
  'Failed to load alarm requests.': 'Hindi ma-load ang mga alarm request.',
  'Failed to load dispatches.': 'Hindi ma-load ang mga dispatch.',
  'Failed to load responder locations.':
      'Hindi ma-load ang lokasyon ng mga responder.',
  'Failed to load reports.': 'Hindi ma-load ang mga report.',
  'Failed to load pending reports.':
      'Hindi ma-load ang mga naghihintay na report.',
  'Failed to load your team.': 'Hindi ma-load ang team mo.',
  'Failed to load your responders.': 'Hindi ma-load ang mga responder mo.',
  '{n} reports': '{n} na report',
  'just now': 'ngayon lang',
  '{n} min ago': '{n} minuto na ang nakalipas',
  '1 hour ago': '1 oras na ang nakalipas',
  '{n} hours ago': '{n} oras na ang nakalipas',
  '1 day ago': '1 araw na ang nakalipas',
  '{n} days ago': '{n} araw na ang nakalipas',
  'Language': 'Wika',
  'Fire Volunteer': 'Fire Volunteer',
  'BFP': 'BFP',
  'Medical': 'Medikal',
  'Police': 'Pulis',
  'Barangay': 'Barangay',
  'We cannot send texts right now. Please try again later.':
      'Hindi kami makapagpadala ng text ngayon. Subukan ulit mamaya.',
  'We could not send the text. Please try again in a minute.':
      'Hindi naipadala ang text. Subukan ulit pagkalipas ng isang minuto.',
  'On the way': 'Papunta na',
  'On scene': 'Nasa lugar na',
  'Fire out': 'Patay na ang sunog',
  'Not confirmed': 'Hindi nakumpirma',
  'Reported': 'Na-report',
  'Show email and mobile': 'Ipakita ang email at mobile',
  'Hide email and mobile': 'Itago ang email at mobile',
  'Waiting for a responding agency to accept it.':
      'Naghihintay pang tanggapin ng isang ahensiya.',
  'Acknowledged. A responding organization is checking it.':
      'Natanggap na. Sinusuri na ito ng isang organisasyon.',
  'No emergency found. Responders checked and closed it.':
      'Walang nakitang emergency. Sinuri at isinara ito ng mga responder.',
  'Responders are on the way.': 'Papunta na ang mga responder.',
  'Responders are on scene.': 'Nasa lugar na ang mga responder.',
  'Fire out. Responders have finished here.':
      'Patay na ang sunog. Tapos na ang mga responder dito.',
  'Closed — it could not be confirmed as an incident.':
      'Sarado na — hindi ito nakumpirmang insidente.',
  'Joined to a neighbouring area.': 'Isinama sa katabing area.',
  'Incident area': 'Area ng insidente',
  'Pasay City': 'Lungsod ng Pasay',
  'One report — no spread yet': 'Isang report pa lang — wala pang pagkalat',
  'Spread over 300 m': 'Kumalat nang higit 300 m',
  'Spread {m} m': 'Kumalat nang {m} m',
  'Confidence': 'Katiyakan',
  'Spatial agreement': 'Pagtutugma ng lokasyon',
  'Source credibility': 'Tiwala sa mga nag-report',
  'Reporters average {n}%': '{n}% ang average ng mga nag-report',
  'Progress': 'Progreso',
  'Step {n} of {of}': 'Hakbang {n} sa {of}',
  'You reported this — follow it': 'Ikaw ang nag-report nito — sundan ito',
  'You\'re {distance} away. A report joins this area only from within 300 m — if you can see something where you are, use SOS.':
      '{distance} ang layo mo. Sumasali lang ang report sa area na ito kung nasa loob ka ng 300 m — kung may nakikita ka kung nasaan ka, gamitin ang SOS.',
  'I see it too — add my report': 'Nakikita ko rin — idagdag ang report ko',
  'Could not open the dialler for {number}.':
      'Hindi mabuksan ang dialer para sa {number}.',
  'Emergency hotlines': 'Mga emergency hotline',
  'Call for help': 'Tumawag ng tulong',
  'Tap to dial. These work without data and without signing in.':
      'I-tap para tumawag. Gumagana ito kahit walang data at kahit hindi naka-sign in.',
  'All hotlines': 'Lahat ng hotline',
  '{category} lines': 'Mga linya ng {category}',
  '{n} numbers': '{n} na numero',
  '{name}, {number}. Tap to dial.': '{name}, {number}. I-tap para tumawag.',
  'Toll-free nationwide': 'Libre saanman sa bansa',
  'Tap to dial': 'I-tap para tumawag',
  'Camera permission denied.': 'Hindi pinayagan ang camera.',
  'Could not start the camera.': 'Hindi masimulan ang camera.',
  'Could not capture the photo. Try again.':
      'Hindi nakuha ang litrato. Subukan ulit.',
  'Flash is not available on this camera.': 'Walang flash ang camera na ito.',
  'Step 2 of 3': 'Hakbang 2 sa 3',
  'SHOW THEM': 'IPAKITA SA KANILA',
  'Starting the camera': 'Binubuksan ang camera',
  'Camera unavailable': 'Hindi magamit ang camera',
  'A live photo of the scene is required to send a report — it is what proves where and when this was taken.':
      'Kailangan ng live na litrato ng lugar para makapag-send ng report — ito ang patunay kung saan at kailan ito kinuha.',
  'Retry camera': 'Subukan ulit ang camera',
  'Location found': 'Nakita na ang lokasyon',
  'Location needed': 'Kailangan ang lokasyon',
  'Locating you…': 'Hinahanap ka…',
  'Geotagged': 'May geotag',
  'Take the photo': 'Kunan ng litrato',
  'Map layers': 'Mga layer ng mapa',
  'Then': 'Pagkatapos',
  'Re-center': 'Ibalik sa gitna',
  'Finding a new route from where you are…':
      'Naghahanap ng bagong ruta mula sa kinaroroonan mo…',
  'Direct line shown — live routing was unavailable. Follow main roads toward the marker.':
      'Tuwid na linya ang nakikita — walang live routing. Sundan ang malalaking kalsada papunta sa marker.',
  'Waiting for GPS — the position shown may be old.':
      'Hinihintay ang GPS — baka luma na ang posisyong nakikita.',
  'Weak GPS signal — your position may be off by {m} m.':
      'Mahina ang GPS — baka mali nang {m} m ang posisyon mo.',
  'You are off the route. We will find you a new one.':
      'Lumabas ka sa ruta. Hahanapan ka namin ng bago.',
  'No live traffic data — times are estimates.':
      'Walang live na traffic data — tantiya lang ang oras.',
  'This route is from the backup router, which cannot check street width.':
      'Galing sa backup router ang rutang ito, kaya hindi nito nasusuri ang lapad ng kalsada.',
  'Your location is off': 'Naka-off ang location mo',
  'We cannot see where you are, so there is no route to draw. Turn on location and allow RepLiT to use it, then try again. The map shows where {place} is.':
      'Hindi namin makita kung nasaan ka, kaya walang rutang maipakita. I-on ang location at payagan ang RepLiT na gamitin ito, saka subukan ulit. Ipinapakita ng mapa kung nasaan ang {place}.',
  'Try again': 'Subukan ulit',
  'You are at the fire': 'Nasa sunog ka na',
  'You have arrived': 'Nakarating ka na',
  'Route to the fire': 'Ruta papunta sa sunog',
  'Route to safety': 'Ruta papunta sa ligtas na lugar',
  'Finding the best route…': 'Hinahanap ang pinakamagandang ruta…',
  'Start': 'Simulan',
  ' · via {road}': ' · dadaan sa {road}',
  '~{n} min': '~{n} min',
  'Voice guidance on': 'Naka-on ang voice guidance',
  'Voice guidance off': 'Naka-off ang voice guidance',
  'Heading up — tap for north up':
      'Nakaharap sa direksiyon mo — i-tap para north up',
  'North up — tap for heading up':
      'North up — i-tap para nakaharap sa direksiyon mo',
  'Hydrants': 'Mga hydrant',
  'Bodies of water': 'Mga pinagkukunan ng tubig',
  'Underground cisterns': 'Mga cistern sa ilalim ng lupa',
  'Water on the way': 'Tubig sa daan',
  'Show where a crew can draw water near the route.':
      'Ipakita kung saan puwedeng kumuha ng tubig malapit sa ruta.',
  'Could not load that layer.': 'Hindi ma-load ang layer na iyan.',
  'You are on scene. Marked arrived.':
      'Nasa lugar ka na. Naka-mark nang dumating.',
  'You are on scene.': 'Nasa lugar ka na.',
  'Could not mark arrived. Check signal.':
      'Hindi ma-mark na dumating. Tingnan ang signal.',
  'Sharing your location': 'Ibinabahagi ang location mo',
  '{distance} straight line': '{distance} tuwid na linya',
  '{distance}, about {n} min': '{distance}, mga {n} min',
  'Mark arrived': 'I-mark na dumating',
  'End navigation': 'Tapusin ang navigation',
  'Done': 'Tapos na',
  'the trip details': 'ang detalye ng biyahe',
  ' via {road}': ' dadaan sa {road}',
  'Switched · {n} min': 'Lumipat · {n} min',
  'Keep to the coral line': 'Sundan ang coral na linya',
  'The old route is now the grey line': 'Ang lumang ruta na ang abuhing linya',
  'Same time': 'Parehong oras',
  'Tap the grey line to switch': 'I-tap ang abuhing linya para lumipat',
  'Another route: {title}. Switch to it': 'Ibang ruta: {title}. Lumipat dito',
  'Looking for an alternative…': 'Naghahanap ng ibang ruta…',
  'The coral line is still your route': 'Ang coral na linya pa rin ang ruta mo',
  'No other route right now': 'Walang ibang ruta sa ngayon',
  'Couldn\'t load a route': 'Hindi ma-load ang ruta',
  'The Area pin and your position are still live. Try again or drive there by sight.':
      'Live pa rin ang pin ng Area at ang posisyon mo. Subukan ulit o pumunta roon nang nakatingin sa daan.',
  'Head to {place}': 'Pumunta sa {place}',
  'Turn-by-turn returns when a route loads':
      'Babalik ang turn-by-turn kapag may rutang na-load',
  'On your way': 'Papunta ka na',
  'Stop': 'Ihinto',
  'Back': 'Bumalik',
  'Profile updated.': 'Na-update na ang profile.',
  'Could not save. Check your connection.':
      'Hindi ma-save. Tingnan ang connection mo.',
  'FULL NAME': 'BUONG PANGALAN',
  'Your full name': 'Ang buong pangalan mo',
  'MOBILE NUMBER': 'MOBILE NUMBER',
  'DATE OF BIRTH': 'PETSA NG KAPANGANAKAN',
  'Edit Profile': 'I-edit ang Profile',
  'Select': 'Pumili',
  'Save changes': 'I-save ang mga pagbabago',
  'Fire': 'Sunog',
  'Health': 'Kalusugan',
  '{n} min': '{n} min',
  'General guidance, not medical advice. If someone is in danger, send an SOS or call 911 first.':
      'Pangkalahatang gabay ito, hindi payong medikal. Kung may nasa panganib, mag-SOS o tumawag muna sa 911.',
  'Call {number}': 'Tumawag sa {number}',
  'Call BFP · {number}': 'Tumawag sa BFP · {number}',
  'Knowledge base': 'Kaalaman',
  'Safety guides': 'Mga gabay sa kaligtasan',
  'Short steps to follow while help is on the way.':
      'Maiikling hakbang na susundin habang papunta ang tulong.',
  'All guides': 'Lahat ng gabay',
  '{n} lessons': '{n} na aralin',
  'Start here: {title}. Open the full guide.':
      'Dito magsimula: {title}. Buksan ang buong gabay.',
  'START HERE · {n} MIN READ': 'DITO MAGSIMULA · {n} MIN NA BASAHIN',
  '{title}, {n} minute read': '{title}, {n} minutong basahin',
  '{n} MIN': '{n} MIN',
  'Frequently asked': 'Mga madalas itanong',
  'Help Center': 'Help Center',
  'In a real emergency': 'Sa totoong emergency',
  'Hold the SOS button, or dial a hotline directly. Do not wait if lives are at risk.':
      'Pindutin nang matagal ang SOS, o tumawag agad sa hotline. Huwag nang maghintay kung may buhay na nasa panganib.',
  'View emergency hotlines': 'Tingnan ang mga emergency hotline',
  'YOU\'RE COVERED': 'PROTEKTADO KA',
  'Hold the SOS button, take one photo, and responders get your exact location with it.':
      'Pindutin nang matagal ang SOS, kumuha ng isang litrato, at makukuha ng mga responder ang eksaktong lokasyon mo.',
  'Location off — tap to turn on': 'Naka-off ang location — i-tap para i-on',
  'No signal — reports will wait': 'Walang signal — maghihintay ang mga report',
  'Connected, location on': 'Konektado, naka-on ang location',
  'SOS. Press and hold for three seconds to start a report.':
      'SOS. Pindutin nang tatlong segundo para magsimula ng report.',
  'SOS': 'SOS',
  'Hold 3 seconds to send': 'Pindutin nang 3 segundo para i-send',
  'Keep holding': 'Huwag bitawan',
  'Only for real emergencies. Every false alert takes a truck away from someone who needs it.':
      'Para lang sa totoong emergency. Bawat maling alerto ay naglalayo ng trak sa taong talagang nangangailangan.',
  'No camera found on this device.': 'Walang camera sa device na ito.',
  'The camera could not start.': 'Hindi nagsimula ang camera.',
  'Could not take the photo. Try again.':
      'Hindi nakuha ang litrato. Subukan ulit.',
  'Camera only — photos from your gallery aren\'t accepted.':
      'Camera lang — hindi tinatanggap ang litrato mula sa gallery.',
  'A live photo is required: saved pictures are not accepted for your National ID.':
      'Kailangan ng live na litrato: hindi tinatanggap ang naka-save na litrato para sa National ID mo.',
  'Close camera': 'Isara ang camera',
  'Location lost': 'Nawala ang lokasyon',
  'Evacuation site': 'Evacuation site',
  'Could not add responders. Check your connection.':
      'Hindi makapagdagdag ng responder. Tingnan ang connection mo.',
  'Responders have your location and photo. A Fire Volunteer coordinator confirms it next. Stay somewhere safe — this screen updates as the incident moves.':
      'Nasa mga responder na ang lokasyon at litrato mo. Kukumpirmahin ito ng isang Fire Volunteer coordinator. Manatili sa ligtas na lugar — nag-a-update ang screen na ito habang umuusad ang insidente.',
  'Acknowledged. A responding organization has seen it and is checking. Stay somewhere safe and keep this screen open — it updates as the incident moves.':
      'Natanggap na. Nakita na ito ng isang organisasyon at sinusuri na. Manatili sa ligtas na lugar at panatilihing bukas ang screen na ito — nag-a-update ito habang umuusad ang insidente.',
  'No emergency found. Responders checked the place and closed it. If you still see a fire, report it again.':
      'Walang nakitang emergency. Sinuri ng mga responder ang lugar at isinara ito. Kung may nakikita ka pang sunog, i-report ulit.',
  'Responders are at the fire. Follow their instructions.':
      'Nasa sunog na ang mga responder. Sundin ang mga utos nila.',
  'Resolved. Thank you for reporting — it is how help found the place.':
      'Naayos na. Salamat sa pag-report — dahil dito, nahanap ng tulong ang lugar.',
  'Closed — a coordinator could not confirm it. If it is still happening, report again or call a hotline.':
      'Sarado na — hindi ito nakumpirma ng coordinator. Kung nangyayari pa, mag-report ulit o tumawag sa hotline.',
  'Joined to a neighbouring area — the same responders have it.':
      'Isinama sa katabing area — parehong mga responder ang may hawak nito.',
  'your report': 'ang report mo',
  'Your area': 'Ang area mo',
  'YOUR REPORT IS LIVE': 'LIVE NA ANG REPORT MO',
  'Fold or open the incident details':
      'Itiklop o buksan ang detalye ng insidente',
  'Status': 'Status',
  'What happens next': 'Ano ang susunod',
  'No neighbours have confirmed yet': 'Wala pang kapitbahay na kumumpirma',
  'Asked within 150 m of the area': 'Tinanong sa loob ng 150 m mula sa area',
  'Nearest open shelter': 'Pinakamalapit na bukas na shelter',
  'WAY': 'DAAN',
  'Seen and being checked': 'Nakita na at sinusuri',
  'A crew is on the way': 'May crew na papunta',
  'You will see the truck here when it shares its location.':
      'Makikita mo rito ang trak kapag ibinahagi nito ang lokasyon.',
  'Responders': 'Mga responder',
  'Need more help?': 'Kailangan pa ng tulong?',
  'Add another kind of responder. They are told where it is straight away — no new photo.':
      'Magdagdag ng ibang uri ng responder. Sasabihan agad sila kung saan ito — walang bagong litrato.',
  'Choose who to add': 'Piliin kung sino ang idadagdag',
  'Add more help': 'Magdagdag ng tulong',
  'Wrong email or password.': 'Mali ang email o password.',
  'Wrong mobile number or password. Not verified your number yet? Use your email instead.':
      'Mali ang mobile number o password. Hindi pa verified ang number mo? Gamitin muna ang email mo.',
  'RESET PASSWORD': 'I-RESET ANG PASSWORD',
  'Enter your account email and we\'ll send a reset link.':
      'Ilagay ang email ng account mo at magpapadala kami ng reset link.',
  'you@email.com': 'you@email.com',
  'CANCEL': 'KANSELAHIN',
  'SEND LINK': 'IPADALA ANG LINK',
  'WELCOME BACK': 'MALIGAYANG PAGBABALIK',
  'Sign in so responders know who is reporting and where to find you.':
      'Mag-sign in para malaman ng mga responder kung sino ang nagre-report at saan ka hahanapin.',
  'Email address': 'Email address',
  'Mobile number': 'Mobile number',
  'Password': 'Password',
  'Your password': 'Ang password mo',
  'Show password': 'Ipakita ang password',
  'Hide password': 'Itago ang password',
  'Use mobile number': 'Gamitin ang mobile number',
  'Use email instead': 'Email na lang ang gamitin',
  'Forgot password?': 'Nakalimutan ang password?',
  'Sign in': 'Mag-sign in',
  'Still signing in. RepLiT can take up to a minute to wake after a quiet spell.':
      'Nagsa-sign in pa. Puwedeng umabot nang isang minuto bago gumising ang RepLiT kapag matagal itong hindi nagamit.',
  'Locked out or offline? Hotlines need no account and no internet.':
      'Hindi maka-sign in o offline? Hindi kailangan ng account o internet sa mga hotline.',
  'New to the app?': 'Bago ka sa app?',
  'Create account': 'Gumawa ng account',
  'A saved report was turned down: {why}':
      'Hindi tinanggap ang isang naka-save na report: {why}',
  'Could not load {layer}.': 'Hindi ma-load ang {layer}.',
  'Location is off. Turn it on to see active areas near you.':
      'Naka-off ang location. I-on ito para makita ang mga aktibong area malapit sa iyo.',
  'Location permission is off. Allow it to see active areas near you.':
      'Hindi pinapayagan ang location. Payagan ito para makita ang mga aktibong area malapit sa iyo.',
  'Could not find your location yet. Move near a window or outdoors.':
      'Hindi pa makita ang lokasyon mo. Lumapit sa bintana o lumabas.',
  'Still no signal. It keeps trying every 15 seconds.':
      'Wala pa ring signal. Sumusubok ulit ito kada 15 segundo.',
  'The server is not taking it yet. It keeps trying every 15 seconds.':
      'Hindi pa ito tinatanggap ng server. Sumusubok ulit ito kada 15 segundo.',
  'Could not open the dialler. Dial 911 directly.':
      'Hindi mabuksan ang dialer. Tumawag nang direkta sa 911.',
  'WATCHING PASAY': 'NAKABANTAY SA PASAY',
  'NO SIGNAL — QUEUED': 'WALANG SIGNAL — NAKAPILA',
  'NO SIGNAL': 'WALANG SIGNAL',
  'RESPONDERS': 'MGA RESPONDER',
  'LOCATING YOU': 'HINAHANAP KA',
  'You\'re here': 'Nandito ka',
  'Showing Pasay City until a fix arrives':
      'Ipinapakita ang Pasay City hanggang makuha ang lokasyon mo',
  'Location on': 'Naka-on ang location',
  'GPS accurate to {m} m': 'Tama ang GPS hanggang {m} m',
  '1 REPORT WAITING': '1 REPORT ANG NAGHIHINTAY',
  '{n} REPORTS WAITING': '{n} REPORT ANG NAGHIHINTAY',
  'Retrying every 15 seconds': 'Sumusubok ulit kada 15 segundo',
  'Waiting on the server — retrying every 15 seconds':
      'Hinihintay ang server — sumusubok ulit kada 15 segundo',
  'Your report and photo are saved on this phone. They send themselves the second you get signal.':
      'Naka-save sa phone na ito ang report at litrato mo. Kusa itong ipapadala pagkakuha mo ng signal.',
  'Try now': 'Subukan ngayon',
  'Call 911': 'Tumawag sa 911',
  'Saved on this phone': 'Naka-save sa phone na ito',
  'Active areas near you': 'Mga aktibong area malapit sa iyo',
  'Live': 'Live',
  'Within 1.5 km': 'Sa loob ng 1.5 km',
  'Checking what is happening around you…':
      'Tinitingnan kung ano ang nangyayari sa paligid mo…',
  'Active areas could not be loaded. The map tries again every 15 seconds.':
      'Hindi ma-load ang mga aktibong area. Sumusubok ulit ang mapa kada 15 segundo.',
  'Nothing active within 1.5 km. That is the good outcome.':
      'Walang aktibo sa loob ng 1.5 km. Magandang balita iyan.',
  'Evacuation site open': 'Bukas ang evacuation site',
  'SPACE FOR {n}': 'KASYA ANG {n}',
  '{kind} report': 'Report ng {kind}',
  'Queued at {time}': 'Nakapila mula {time}',
  'QUEUED': 'NAKAPILA',
  'Map layers not saved yet': 'Hindi pa naka-save ang mga layer ng mapa',
  'Map layers cached': 'Naka-save na ang mga layer ng mapa',
  'They save the next time the map has signal':
      'Mase-save ito sa susunod na may signal ang mapa',
  'Downloaded {ago}': 'Na-download {ago}',
  'READY': 'HANDA',
  'All {n} hotlines': 'Lahat ng {n} na hotline',
  'Dial without data': 'Tumawag kahit walang data',
  'Emergency': 'Emergency',
  'SHELTER · OUTSIDE PASAY': 'SHELTER · LABAS NG PASAY',
  'Not at the moment': 'Hindi sa ngayon',
  'Risk level': 'Antas ng panganib',
  'Fire hydrant': 'Fire hydrant',
  'Body of water': 'Pinagkukunan ng tubig',
  'Underground cistern': 'Cistern sa ilalim ng lupa',
  '{area}, {n} reports, {band} confidence':
      '{area}, {n} na report, {band} na katiyakan',
  '1 REPORT': '1 REPORT',
  '{n} REPORTS': '{n} NA REPORT',
  'Earlier': 'Mas maaga',
  'This month': 'Ngayong buwan',
  'Your reports': 'Ang mga report mo',
  'Could not load your reports': 'Hindi ma-load ang mga report mo',
  'Sent': 'Naipadala',
  'Active': 'Aktibo',
  'Resolved': 'Naayos na',
  'Nothing sent yet': 'Wala ka pang naipadala',
  'Reports you send appear here with what came of them — who was sent, and when it was resolved.':
      'Lalabas dito ang mga report na ipinadala mo at kung ano ang nangyari — sino ang ipinadala, at kailan ito naayos.',
  'Other residents never see your name or your photos — only the responders and barangay staff handling the incident do.':
      'Hindi kailanman makikita ng ibang residente ang pangalan o litrato mo — ang mga responder at staff ng barangay lang na humahawak sa insidente.',
  'Date unknown': 'Hindi alam ang petsa',
  'Today at {time}': 'Ngayong araw, {time}',
  'Closed — it could not be confirmed': 'Sarado na — hindi ito nakumpirma',
  'Joined to a neighbouring incident': 'Isinama sa katabing insidente',
  'Waiting to be grouped with others': 'Naghihintay na maipangkat sa iba',
  'Being double-checked — the photo and your phone disagreed on where it was taken.':
      'Sinusuri pa ulit — hindi magkatugma ang litrato at ang phone mo sa kung saan ito kinuha.',
  'Submitted for review. An admin will award +50% once approved.':
      'Naipadala na para suriin. Makukuha mo ang +50% kapag inaprubahan ng admin.',
  'VERIFY YOUR IDENTITY': 'I-VERIFY ANG PAGKAKAKILANLAN MO',
  'Photograph your PhilID card or ePhilID and its QR code, then take a matching selfie. All three must be taken now with the camera — saved pictures are not accepted. An administrator checks the QR code on PSA\'s PhilSys Check and awards +50%.':
      'Kunan ng litrato ang PhilID card o ePhilID mo at ang QR code nito, saka kumuha ng selfie na kamukha mo. Kailangang kunan ang tatlo ngayon gamit ang camera — hindi tinatanggap ang naka-save na litrato. Susuriin ng isang administrator ang QR code sa PhilSys Check ng PSA at bibigyan ka ng +50%.',
  'National ID': 'National ID',
  'Tap to photograph the side with your picture':
      'I-tap para kunan ang side na may litrato mo',
  'QR code': 'QR code',
  'On the back of the card. Tap to photograph it.':
      'Nasa likod ng card. I-tap para kunan ito.',
  'Selfie': 'Selfie',
  'Tap to take a selfie': 'I-tap para mag-selfie',
  'I agree to an administrator checking my QR code on PSA\'s PhilSys Check. PSA records the date, my first name and the result.':
      'Pumapayag ako na suriin ng isang administrator ang QR code ko sa PhilSys Check ng PSA. Itatala ng PSA ang petsa, ang first name ko at ang resulta.',
  'TAP TO RETAKE': 'I-TAP PARA KUNAN ULIT',
  'Submit for review': 'Ipadala para suriin',
  'Your photos are held in private storage, seen only by the reviewing administrator, and deleted once the review is decided. The +50% applies once it is approved.':
      'Nakatago sa private storage ang mga litrato mo, makikita lang ng administrator na sumusuri, at buburahin kapag tapos na ang pagsusuri. Makukuha ang +50% kapag naaprubahan.',
  'Your answer did not reach RepLiT. Check your signal and try again.':
      'Hindi umabot sa RepLiT ang sagot mo. Tingnan ang signal mo at subukan ulit.',
  'Could not open the dialer for 911.':
      'Hindi mabuksan ang dialer para sa 911.',
  'Someone within {m} metres reported a fire near you.':
      'May nag-report ng sunog malapit sa iyo, sa loob ng {m} metro.',
  'Someone within {m} metres reported a fire near you {ago}.':
      'May nag-report ng sunog malapit sa iyo, sa loob ng {m} metro, {ago}.',
  'Someone within {m} metres reported a fire on {street}.':
      'May nag-report ng sunog sa {street}, sa loob ng {m} metro mula sa iyo.',
  'Someone within {m} metres reported a fire on {street} {ago}.':
      'May nag-report ng sunog sa {street}, sa loob ng {m} metro mula sa iyo, {ago}.',
  'a minute ago': 'isang minuto na ang nakalipas',
  '{n} minutes ago': '{n} minuto na ang nakalipas',
  'an hour ago': 'isang oras na ang nakalipas',
  'Your answer did not reach RepLiT, so you may be asked again. Check your connection and try once more.':
      'Hindi umabot sa RepLiT ang sagot mo, kaya baka tanungin ka ulit. Tingnan ang connection mo at subukan pa ulit.',
  'You won\'t be asked about this one again.':
      'Hindi ka na tatanungin ulit tungkol dito.',
  'DO YOU SEE IT TOO?': 'NAKIKITA MO RIN BA?',
  'Confirming takes you through the same photo step, so your answer becomes a real report — not just a tap.':
      'Dadaan ang pagkumpirma sa parehong hakbang ng litrato, kaya magiging totoong report ang sagot mo — hindi lang isang tap.',
  'Need help now? Call 911': 'Kailangan ng tulong ngayon? Tumawag sa 911',
  'Yes, I can see it': 'Oo, nakikita ko',
  'Close': 'Isara',
  'No, and stop asking about this':
      'Hindi, at huwag na akong tanungin tungkol dito',
  'NEARBY FIRE ALERT': 'ALERTO: MAY SUNOG MALAPIT',
  'Loading the map': 'Nilo-load ang mapa',
  '{distance} FROM YOU': '{distance} MULA SA IYO',
  'Could not load notifications.': 'Hindi ma-load ang mga notification.',
  'There is nothing to open for this one.': 'Walang mabubuksan para dito.',
  'New fire': 'Bagong sunog',
  'Fire alert': 'Alerto sa sunog',
  'Incident update': 'Update sa insidente',
  'Dispatched unit': 'Ipinadalang unit',
  'Routed to your team': 'Ipinasa sa team mo',
  'Alarm request': 'Alarm request',
  'Alarm raised': 'Itinaas ang alarm',
  'BFP answered': 'Sumagot ang BFP',
  'Nothing unread': 'Walang hindi pa nababasa',
  'Alerts': 'Mga alerto',
  'Mark all read': 'Markahang nabasa lahat',
  'Could not load alerts': 'Hindi ma-load ang mga alerto',
  'No alerts yet': 'Wala pang alerto',
  'If something is reported near you, an alert appears here so you can confirm or dismiss it.':
      'Kapag may nag-report malapit sa iyo, lalabas dito ang alerto para makumpirma mo o ma-dismiss.',
  'Could not send a test notification.':
      'Hindi makapagpadala ng test notification.',
  'Notifications': 'Mga notification',
  'EMERGENCY ALERTS': 'MGA EMERGENCY ALERT',
  'Get alerted about incidents reported near you.':
      'Maalerto tungkol sa mga insidenteng iniulat malapit sa iyo.',
  'Send test notification': 'Magpadala ng test notification',
  'Turning alerts off unregisters this device, so nearby-incident notifications stop until you turn it back on. Alerts still appear in the inbox.':
      'Kapag in-off ang mga alerto, aalisin ang device na ito, kaya titigil ang mga notification tungkol sa malapit na insidente hanggang i-on mo ulit. Lalabas pa rin ang mga alerto sa inbox.',
  'Step {n} of 6': 'Hakbang {n} sa 6',
  'Skip': 'Laktawan',
  'Hi, I\'m Lit.': 'Hi, ako si Lit.',
  'I\'m a firefly. I\'ll show you how to report an emergency here — about a minute.':
      'Alitaptap ako. Ipapakita ko sa iyo kung paano mag-report ng emergency dito — mga isang minuto lang.',
  'Show me around': 'Ipakita mo sa akin',
  'Skip for now': 'Laktawan muna',
  'Hold SOS for three seconds': 'Pindutin nang tatlong segundo ang SOS',
  'A tap sends nothing. Holding is what starts a report, so it can\'t happen by accident in your pocket.':
      'Walang naipapadala sa isang tap. Ang matagal na pagpindot ang nagsisimula ng report, kaya hindi ito mangyayari nang hindi sinasadya sa bulsa mo.',
  'Next': 'Susunod',
  'Pick who should come, then take one photo':
      'Piliin kung sino ang darating, saka kumuha ng isang litrato',
  'Fire, police, medical, barangay — one or several. The photo is required: it tells the responders what they are driving into.':
      'Sunog, pulis, medikal, barangay — isa o ilan. Kailangan ang litrato: dito makikita ng mga responder kung ano ang dadatnan nila.',
  'One photo of the scene': 'Isang litrato ng lugar',
  'Required — there is no skip': 'Kailangan — hindi puwedeng laktawan',
  'Reports near each other become one':
      'Nagiging isa ang mga report na magkakalapit',
  'If a neighbour reports the same fire, RepLiT groups it with yours into a single Area — so responders see one incident, not five.':
      'Kapag na-report din ng kapitbahay ang parehong sunog, pagsasamahin ito ng RepLiT sa report mo bilang isang Area — kaya isang insidente ang makikita ng mga responder, hindi lima.',
  'Area confidence': 'Katiyakan ng area',
  'Medium': 'Katamtaman',
  'You may be asked to confirm': 'Baka tanungin ka para kumpirmahin',
  'When something is reported within 150 metres of you, RepLiT asks one question. Answering makes the report more certain.':
      'Kapag may na-report sa loob ng 150 metro mula sa iyo, isang tanong ang itatanong ng RepLiT. Kapag sumagot ka, mas tiyak ang report.',
  'Do you see it too?': 'Nakikita mo rin ba?',
  'Fire reported 180 m from you': 'May sunog na na-report 180 m mula sa iyo',
  'Yes, report it': 'Oo, i-report ito',
  'Practice — nothing is sent': 'Practice — walang ipapadala',
  'Practice SOS dial. Hold for three seconds. Nothing is sent.':
      'Practice na SOS. Pindutin nang tatlong segundo. Walang ipapadala.',
  'That\'s it. Nothing was sent — this was practice.':
      'Iyon na iyon. Walang naipadala — practice lang ito.',
  'Keep your finger down until the ring closes.':
      'Huwag iangat ang daliri hanggang magsara ang bilog.',
  'I\'ve got it': 'Nakuha ko na',
  'Skip practice': 'Laktawan ang practice',
  'You\'re ready': 'Handa ka na',
  'Verify your account when you have time':
      'I-verify ang account mo kapag may oras ka',
  'It makes your reports count for more. You never need it to report.':
      'Mas bibigyang-halaga ang mga report mo. Hindi mo ito kailangan para makapag-report.',
  'Open the map': 'Buksan ang mapa',
  'Your number is verified.': 'Verified na ang number mo.',
  'Verify your number': 'I-verify ang number mo',
  'Enter the code we sent to {to}.':
      'Ilagay ang code na ipinadala namin sa {to}.',
  'your phone': 'phone mo',
  'We will send a 6-digit code to your phone by text. You need to do this once before you can use RepLiT.':
      'Magpapadala kami ng 6-digit na code sa phone mo sa pamamagitan ng text. Kailangan mo itong gawin minsan bago mo magamit ang RepLiT.',
  'We will send a 6-digit code to your phone by text. It adds 40% to your trust level.':
      'Magpapadala kami ng 6-digit na code sa phone mo sa pamamagitan ng text. Dagdag ito na 40% sa trust level mo.',
  'Verify code': 'I-verify ang code',
  'Send code': 'Ipadala ang code',
  'Send again in {s} s': 'Ipadala ulit sa loob ng {s} s',
  'Send the code again': 'Ipadala ulit ang code',
  'Use a different number': 'Gumamit ng ibang number',
  'We use your number to check that you are a real person, and to contact you about your reports. We never ask for this code by call or chat. Do not share it.':
      'Ginagamit namin ang number mo para masigurong totoong tao ka, at para makontak ka tungkol sa mga report mo. Hindi namin hihingin ang code na ito sa tawag o chat. Huwag itong ibigay kahit kanino.',
  'RepLiT user': 'RepLiT user',
  'Fire alerts with the app closed': 'Mga alerto sa sunog kahit sarado ang app',
  'RepLiT tells you about a fire within 150 m of where you are now. To know that while the app is closed, it needs your location "All the time". It sends it to RepLiT about every 15 minutes, and only for these alerts.':
      'Sinasabihan ka ng RepLiT tungkol sa sunog sa loob ng 150 m mula sa kinaroroonan mo ngayon. Para malaman iyon kahit sarado ang app, kailangan nito ang location mo nang "Palagi" ("All the time"). Ipinapadala ito sa RepLiT mga bawat 15 minuto, at para lang sa mga alertong ito.',
  'Not now': 'Hindi muna',
  'Allow': 'Payagan',
  'ABOUT REPLIT': 'TUNGKOL SA REPLIT',
  'RepLiT is the emergency reporting network for Pasay City. Report an incident, see what is happening near you and where the shelters are, learn the basics, and reach responders fast.':
      'Ang RepLiT ang emergency reporting network ng Pasay City. Mag-report ng insidente, tingnan ang nangyayari malapit sa iyo at kung nasaan ang mga shelter, matuto ng mga basic, at makontak agad ang mga responder.',
  'In a real emergency, hold SOS or call 911.':
      'Sa totoong emergency, pindutin nang matagal ang SOS o tumawag sa 911.',
  'Account': 'Account',
  'Your profile': 'Ang profile mo',
  'Account details': 'Detalye ng account',
  'Edit': 'I-edit',
  'Settings': 'Settings',
  'Barangay alerts': 'Mga alerto ng barangay',
  'Fires reported within 150 m, and news on your reports':
      'Mga sunog na na-report sa loob ng 150 m, at balita sa mga report mo',
  'On. Fires within 150 m reach you even when RepLiT is closed.':
      'Naka-on. Aabot sa iyo ang mga sunog sa loob ng 150 m kahit sarado ang RepLiT.',
  'Allow location "All the time" so fires within 150 m reach you when RepLiT is closed.':
      'Payagan ang location nang "Palagi" ("All the time") para umabot sa iyo ang mga sunog sa loob ng 150 m kahit sarado ang RepLiT.',
  'Light mode': 'Light mode',
  'The pale ground, for daylight': 'Maliwanag na kulay, para sa araw',
  'Your alerts come in the same language':
      'Sa parehong wika darating ang mga alerto mo',
  'Send a test alert': 'Magpadala ng test alert',
  'Check this phone receives them':
      'Tingnan kung natatanggap ito ng phone na ito',
  'More': 'Iba pa',
  'Everything you have sent, and where it got to':
      'Lahat ng naipadala mo, at kung ano na ang nangyari',
  'Alerts and updates sent to you': 'Mga alerto at update na ipinadala sa iyo',
  'Help center': 'Help center',
  'How reporting works, and what happens next':
      'Paano mag-report, at ano ang susunod na mangyayari',
  'About RepLiT': 'Tungkol sa RepLiT',
  'Emergency reporting for Pasay City':
      'Emergency reporting para sa Pasay City',
  'Check for updates': 'Tingnan kung may update',
  'Get the newest version of RepLiT':
      'Kunin ang pinakabagong bersiyon ng RepLiT',
  'Version {v} installed': 'Naka-install ang bersiyon {v}',
  'Log out': 'Mag-log out',
  'REPLIT · PASAY CITY': 'REPLIT · PASAY CITY',
  'Your National ID is being checked': 'Sinusuri pa ang National ID mo',
  'Its 50% applies once an administrator approves it':
      'Makukuha ang 50% nito kapag inaprubahan ng isang administrator',
  'Add your National ID for +50%': 'Idagdag ang National ID mo para sa +50%',
  'Responders weigh verified reports more heavily':
      'Mas pinahahalagahan ng mga responder ang mga verified na report',
  'Confirm your email for +10%': 'Kumpirmahin ang email mo para sa +10%',
  'One tap on a link we send you': 'Isang tap lang sa link na ipapadala namin',
  'Add your mobile number for +40%':
      'Idagdag ang mobile number mo para sa +40%',
  'Confirmed with a code by SMS': 'Kinukumpirma gamit ang code sa SMS',
  'Email': 'Email',
  'Mobile': 'Mobile',
  'Not added yet': 'Wala pa',
  'Please enter your full name.': 'Ilagay ang buong pangalan mo.',
  'Enter your mobile number, like 0917 123 4567.':
      'Ilagay ang mobile number mo, gaya ng 0917 123 4567.',
  'Please enter a valid email address.': 'Maglagay ng tamang email address.',
  'Password must be at least 8 characters.':
      'Dapat hindi bababa sa 8 character ang password.',
  'Please agree to sharing your location and reports.':
      'Pumayag muna sa pagbabahagi ng location at mga report mo.',
  'Could not reach the server. Check the API URL in api_config.dart.':
      'Hindi ma-contact ang server. Tingnan ang API URL sa api_config.dart.',
  'CREATE YOUR ACCOUNT': 'GUMAWA NG ACCOUNT MO',
  'We will text a code to your mobile number to check it is yours. You sign in with it from then on.':
      'Magte-text kami ng code sa mobile number mo para masigurong sa iyo ito. Iyon na ang gagamitin mo sa pag-sign in mula ngayon.',
  'Full name': 'Buong pangalan',
  'As on your ID': 'Gaya ng nasa ID mo',
  'At least 8 characters': 'Hindi bababa sa 8 character',
  'Your trust level, up to 100%': 'Ang trust level mo, hanggang 100%',
  'I agree that my location and reports may be shared with responders and their agencies during an emergency.':
      'Pumapayag ako na maibahagi ang location at mga report ko sa mga responder at sa kanilang ahensiya habang may emergency.',
  'You already have a report in progress. It stays open until the fire is out.':
      'May report ka pang tumatakbo. Bukas ito hanggang mapatay ang sunog.',
  'Your report is saved on this phone. It sends itself when the signal is back.':
      'Naka-save sa phone na ito ang report mo. Kusa itong ipapadala pagbalik ng signal.',
  'Grouped with reports within 300 m': 'Isinama sa mga report sa loob ng 300 m',
  'Within 300 m of an active area': 'Nasa loob ng 300 m ng isang aktibong area',
  'A new area — the first report here': 'Bagong area — ang unang report dito',
  'Report done': 'Tapos na ang report',
  'Report closed': 'Sarado na ang report',
  'Report sent': 'Naipadala ang report',
  'FIRE OUT': 'PATAY NA ANG SUNOG',
  'NOT CONFIRMED': 'HINDI NAKUMPIRMA',
  'GETTING YOU HELP': 'PINAPADALHAN KA NG TULONG',
  'Responders have put the fire out. Thank you for reporting — your report is done.':
      'Napatay na ng mga responder ang sunog. Salamat sa pag-report — tapos na ang report mo.',
  'A coordinator could not confirm this one. If it is still happening, send another report or call a hotline.':
      'Hindi ito nakumpirma ng coordinator. Kung nangyayari pa, magpadala ng isa pang report o tumawag sa hotline.',
  'You do not need to do anything else. This screen follows your report until the fire is out — SOS brings you back here.':
      'Wala ka nang ibang kailangang gawin. Sinusundan ng screen na ito ang report mo hanggang mapatay ang sunog — ibabalik ka rito ng SOS.',
  'Report received': 'Natanggap ang report',
  'Photo and GPS stored': 'Naka-save ang litrato at GPS',
  'Responders notified': 'Naabisuhan ang mga responder',
  'Neighbours within 150 m were alerted too':
      'Inalerto rin ang mga kapitbahay sa loob ng 150 m',
  'Waiting to be accepted': 'Naghihintay na tanggapin',
  'Closed by a coordinator': 'Isinara ng isang coordinator',
  'Responders reached the scene': 'Nakarating na sa lugar ang mga responder',
  'Responders are on the way': 'Papunta na ang mga responder',
  'Open it from Your reports to follow it':
      'Buksan ito sa Ang mga report mo para masundan',
  'Your report is done': 'Tapos na ang report mo',
  'Responders are working on it': 'Inaasikaso na ito ng mga responder',
  'Once responders are on scene': 'Kapag nasa lugar na ang mga responder',
  'Track it live': 'Sundan nang live',
  'Something else? Call a hotline': 'May iba pa? Tumawag sa hotline',
  'ENCRYPTED, SHARED ONLY WITH RESPONDERS':
      'NAKA-ENCRYPT, SA MGA RESPONDER LANG IBINABAHAGI',
  'Retry': 'Subukan ulit',
  'Sign in again': 'Mag-sign in ulit',
  'Still connecting. RepLiT can take up to a minute to wake after a quiet spell.':
      'Kumokonekta pa. Puwedeng umabot nang isang minuto bago gumising ang RepLiT kapag matagal itong hindi nagamit.',
  'Could not pinpoint your location. Move near a window or outdoors and try again.':
      'Hindi matukoy ang lokasyon mo. Lumapit sa bintana o lumabas, saka subukan ulit.',
  'Could not submit the report. Check your connection.':
      'Hindi naipadala ang report. Tingnan ang connection mo.',
  'Could not submit the report or save it. Check your connection.':
      'Hindi naipadala o na-save ang report. Tingnan ang connection mo.',
  'WHAT ARE WE SENDING?': 'ANO ANG IPAPADALA NATIN?',
  'Who should respond': 'Sino ang dapat tumugon',
  'Photo of the scene': 'Litrato ng lugar',
  'Required': 'Kailangan',
  'Anything else': 'May iba pa',
  'Optional — what responders should know':
      'Opsiyonal — ano ang dapat malaman ng mga responder',
  'Pinpointing your location — your report sends the moment it is found.':
      'Hinahanap ang eksaktong lokasyon mo — ipapadala ang report mo kapag nakita na ito.',
  'Choose who to call': 'Piliin kung sino ang tatawagan',
  'Send report': 'Ipadala ang report',
  'LOCATION LOCKED': 'NAKUHA NA ANG LOKASYON',
  'FINDING YOUR LOCATION': 'HINAHANAP ANG LOKASYON MO',
  '{agency}, always included': '{agency}, laging kasama',
  'Fire is always included. Add any other help you need.':
      'Laging kasama ang Sunog. Idagdag ang iba pang tulong na kailangan mo.',
  'Pinpointing your location…': 'Hinahanap ang eksaktong lokasyon mo…',
  'Geotagged, {place}': 'May geotag, {place}',
  'Photo of the scene. Tap to take it again.':
      'Litrato ng lugar. I-tap para kunan ulit.',
  'Retake': 'Kunan ulit',
  'Connecting to RepLiT': 'Kumokonekta sa RepLiT',
  'EMERGENCY RESPONSE NETWORK': 'NETWORK PARA SA EMERGENCY',
  'VERIFY YOUR ACCOUNT': 'I-VERIFY ANG ACCOUNT MO',
  'Verification never blocks a report. It tells responders how much weight to give what you send.':
      'Hindi kailanman haharangin ng verification ang report. Sinasabi lang nito sa mga responder kung gaano kabigat ang ipinapadala mo.',
  'Channels': 'Mga paraan',
  'Badges': 'Mga badge',
  'Under 50': 'Mababa sa 50',
  'Documents are held privately, used only to confirm who you are, and deleted after review. A National ID is checked by an administrator on PSA\'s PhilSys Check before its 50% applies.':
      'Pribadong itinatago ang mga dokumento, ginagamit lang para kumpirmahin kung sino ka, at binubura pagkatapos suriin. Sinusuri ng isang administrator ang National ID sa PhilSys Check ng PSA bago makuha ang 50% nito.',
  'Verified': 'Verified',
  'Unavailable while we change SMS provider':
      'Hindi pa magagamit habang nagpapalit kami ng SMS provider',
  'Confirm it with a code by SMS': 'Kumpirmahin gamit ang code sa SMS',
  'Submitted — an administrator is checking it':
      'Naipadala na — sinusuri ito ng isang administrator',
  'Not accepted — take the photos again':
      'Hindi tinanggap — kunan ulit ang mga litrato',
  'Camera only — ID, QR code and selfie must be live':
      'Camera lang — dapat live ang ID, QR code at selfie',
  'Link sent — open it on this phone':
      'Naipadala na ang link — buksan ito sa phone na ito',
  'Tap for a confirmation link': 'I-tap para sa confirmation link',
  '{channel}, plus {n} percent. {line}':
      '{channel}, dagdag na {n} porsiyento. {line}',
  'CONFIRM YOUR EMAIL': 'KUMPIRMAHIN ANG EMAIL MO',
  'The link is on its way. Open it on this phone, then come back — your level updates by itself.':
      'Papunta na ang link. Buksan ito sa phone na ito, saka bumalik — kusang mag-a-update ang level mo.',
  'We\'ll email you a secure link. Opening it on this phone confirms the address.':
      'Magpapadala kami ng ligtas na link sa email mo. Kapag binuksan mo ito sa phone na ito, makukumpirma ang email.',
  'Send the link': 'Ipadala ang link',
  'Send it again': 'Ipadala ulit',
  'Developer options are on': 'Naka-on ang Developer options',
  'Our system found settings on this phone that are not secure: Developer options are on.':
      'May nakita ang system namin na settings sa phone na ito na hindi ligtas: naka-on ang Developer options.',
  'Our system found settings on this phone that are not secure: Developer options and USB debugging are on.':
      'May nakita ang system namin na settings sa phone na ito na hindi ligtas: naka-on ang Developer options at USB debugging.',
  'They let other apps fake your location, and every report needs your real one. Turn them off in your phone\'s Settings, then open RepLiT again.':
      'Dahil dito, puwedeng gawing peke ng ibang app ang lokasyon mo, pero kailangan ng bawat report ang totoo mong lokasyon. I-off ang mga ito sa Settings ng phone mo, saka buksan ulit ang RepLiT.',
  'Exit': 'Lumabas',
  'In an emergency, call 911': 'Kung may emergency, tumawag sa 911',
  'No connection. Check your internet and try again.':
      'Walang connection. Tingnan ang internet mo at subukan ulit.',
  'The download didn\'t finish. Check your connection and try again.':
      'Hindi natapos ang download. Tingnan ang connection mo at subukan ulit.',
  'The download was damaged on the way. Try again.':
      'Nasira ang download habang dumarating. Subukan ulit.',
  'The newest release can\'t be read. Please tell the RepLiT team.':
      'Hindi mabasa ang pinakabagong release. Pakisabi sa RepLiT team.',
  'This build can\'t install updates. Ask the RepLiT team for the newest one.':
      'Hindi makapag-install ng update ang build na ito. Hingin sa RepLiT team ang pinakabago.',
  'Android couldn\'t open the installer. Try again in a little while.':
      'Hindi mabuksan ng Android ang installer. Subukan ulit maya-maya.',
  'You already have the newest version.':
      'Nasa iyo na ang pinakabagong bersiyon.',
  'Couldn\'t check for updates. Try again in a little while.':
      'Hindi makatingin ng update. Subukan ulit maya-maya.',
  'CHECK FOR UPDATES': 'TINGNAN KUNG MAY UPDATE',
  'Installed: version {v}': 'Naka-install: bersiyon {v}',
  'Looking for a newer version…': 'Naghahanap ng mas bagong bersiyon…',
  'You have the latest version.': 'Nasa iyo na ang pinakabagong bersiyon.',
  'Version {v} is ready.': 'Handa na ang bersiyon {v}.',
  'Download: {size}. Wi-Fi is best.':
      'Laki ng download: {size}. Mas mabuti kung naka-Wi-Fi.',
  'Download and install': 'I-download at i-install',
  'Downloading…': 'Dina-download…',
  'Downloading… {n}%': 'Dina-download… {n}%',
  'Android will ask you to confirm the install. The first time, it also asks you to allow installs from RepLiT.':
      'Hihingin ng Android na kumpirmahin mo ang pag-install. Sa unang beses, hihingin din nitong payagan ang pag-install mula sa RepLiT.',
  'Downloaded. Finish the install in the window Android opened.':
      'Na-download na. Tapusin ang pag-install sa window na binuksan ng Android.',
  'Version {v} is downloaded and ready to install.':
      'Na-download na ang bersiyon {v} at handa nang i-install.',
  'Install': 'I-install',
  'Opening the installer…': 'Binubuksan ang installer…',
  'Open the installer again': 'Buksan ulit ang installer',
  'SOS — hold to report': 'SOS — pindutin nang matagal para mag-report',
  '{tab}, tab {n} of {of}': '{tab}, tab {n} sa {of}',
  'Hide {what}': 'Itago ang {what}',
  'Show {what}': 'Ipakita ang {what}',
  'the incident': 'ang insidente',
  'A quick tour of the map': 'Maikling tour ng mapa',
  'Reports group into Areas': 'Nagsasama-sama ang mga report bilang Area',
  'Three neighbours reporting the same fire show up here as one incident, not three.':
      'Kapag tatlong kapitbahay ang nag-report ng iisang sunog, lalabas ito rito bilang isang insidente, hindi tatlo.',
  'SOS lives here': 'Nandito ang SOS',
  'Hold it for three seconds from any screen. A tap does nothing.':
      'Pindutin ito nang tatlong segundo mula sa kahit anong screen. Walang mangyayari sa isang tap.',
  'Got it': 'Sige',
  'Map tilt {n} degrees. Tap for {next} degrees':
      'Nakatagilid ang mapa nang {n} degrees. I-tap para gawing {next} degrees',
  'Map tilt unavailable on the flat map':
      'Hindi puwedeng itagilid ang patag na mapa',
  'ENTER THE CODE': 'ILAGAY ANG CODE',
  'Sending a code to {phone}…': 'Nagpapadala ng code sa {phone}…',
  'We sent a 6-digit code to {phone}. It works for 5 minutes.':
      'Nagpadala kami ng 6-digit na code sa {phone}. Gumagana ito nang 5 minuto.',
  'Verify': 'I-verify',
  'Later': 'Mamaya na',
  'Report photo': 'Litrato ng report',
  'Loading the photo': 'Nilo-load ang litrato',
  'The photo could not be loaded.': 'Hindi ma-load ang litrato.',
  'Close photo': 'Isara ang litrato',
  'Pinch or double-tap to zoom': 'I-pinch o i-double tap para mag-zoom',
  'Point the map north': 'Iharap sa hilaga ang mapa',
  'Show where I am': 'Ipakita kung nasaan ako',
  'Turn the map with me': 'Iikot ang mapa kasabay ko',
  'Stop turning the map': 'Itigil ang pag-ikot ng mapa',
  'FIRE PREVENTION': 'PAG-IWAS SA SUNOG',
  'HEALTH': 'KALUSUGAN',
  'Prevent Common Fire Hazards': 'Iwasan ang Karaniwang Sanhi ng Sunog',
  'Inspect wiring, unplug idle appliances, and keep flammables away from heat sources.':
      'Suriin ang wiring, bunutin sa saksakan ang mga appliance na hindi ginagamit, at ilayo sa init ang mga bagay na madaling magliyab.',
  'Most home fires start from everyday hazards that are easy to control. A few minutes of checking can prevent a tragedy.':
      'Karamihan sa sunog sa bahay ay nagsisimula sa mga pang-araw-araw na panganib na madaling kontrolin. Ilang minutong pagsusuri lang, puwedeng makaiwas sa trahedya.',
  'Electrical safety': 'Kaligtasan sa kuryente',
  'Inspect cords for fraying, cracks, or exposed wires and replace damaged ones.':
      'Tingnan kung may punit, bitak, o lantad na wire ang mga kordon at palitan ang mga sira.',
  'Avoid overloading outlets and extension cords (\'octopus\' connections).':
      'Huwag pagsabay-sabayin ang maraming saksak sa isang outlet o extension cord (\'octopus\' na koneksiyon).',
  'Unplug irons, chargers, and appliances when they are not in use.':
      'Bunutin sa saksakan ang plantsa, charger, at mga appliance kapag hindi ginagamit.',
  'Have a licensed electrician check old or faulty wiring.':
      'Ipasuri sa lisensiyadong electrician ang luma o sirang wiring.',
  'In the kitchen': 'Sa kusina',
  'Never leave cooking unattended, especially when frying.':
      'Huwag iwanan ang niluluto, lalo na kapag nagpiprito.',
  'Keep curtains, paper, and plastic well away from the stove.':
      'Ilayo nang husto sa kalan ang kurtina, papel, at plastik.',
  'Close the LPG tank valve after cooking and check hoses for leaks.':
      'Isara ang valve ng tangke ng LPG pagkatapos magluto at tingnan kung may tagas ang hose.',
  'Open flame and smoking': 'Apoy at paninigarilyo',
  'Keep candles, matches, and lighters out of reach of children.':
      'Ilayo sa abot ng mga bata ang kandila, posporo, at lighter.',
  'Put out cigarettes completely and never smoke in bed.':
      'Patayin nang tuluyan ang sigarilyo at huwag manigarilyo sa kama.',
  'Store gasoline and flammable liquids outside, in sealed containers.':
      'Itago sa labas ng bahay ang gasolina at mga likidong madaling magliyab, sa saradong lalagyan.',
  'Smoke Alarm Maintenance': 'Pag-aalaga sa Smoke Alarm',
  'Test alarms monthly, replace batteries yearly, and swap units every 10 years.':
      'Subukan ang alarm buwan-buwan, palitan ang baterya taon-taon, at palitan ang unit kada 10 taon.',
  'A working smoke alarm gives you the early warning you need to escape. Maintenance takes only minutes.':
      'Ang gumaganang smoke alarm ang maagang babala na kailangan mo para makatakas. Ilang minuto lang ang pag-aalaga rito.',
  'Where to place them': 'Saan ilalagay',
  'Install alarms inside each bedroom and on every level of the home.':
      'Maglagay ng alarm sa bawat kuwarto at sa bawat palapag ng bahay.',
  'Mount on the ceiling or high on a wall, away from vents and windows.':
      'Ikabit sa kisame o mataas sa dingding, malayo sa bentilasyon at bintana.',
  'Monthly and yearly': 'Buwan-buwan at taon-taon',
  'Press the test button every month to confirm it sounds.':
      'Pindutin ang test button buwan-buwan para masigurong tumutunog ito.',
  'Replace the battery at least once a year, or as soon as it chirps.':
      'Palitan ang baterya kahit isang beses sa isang taon, o agad kapag nag-beep na ito.',
  'Clear dust away with a vacuum or a soft brush.':
      'Alisin ang alikabok gamit ang vacuum o malambot na brush.',
  'When to replace': 'Kailan papalitan',
  'Replace the entire unit every 10 years.':
      'Palitan ang buong unit kada 10 taon.',
  'Never disable an alarm for nuisance cooking smoke — relocate it instead.':
      'Huwag patayin ang alarm dahil tumutunog ito sa usok ng niluluto — ilipat na lang ito ng puwesto.',
  'Build an Escape Plan': 'Gumawa ng Plano sa Pagtakas',
  'Map two exits per room, agree on a meet point, and practice with your household.':
      'Alamin ang dalawang labasan sa bawat kuwarto, magkasundo sa isang tagpuan, at magpraktis kasama ang pamilya.',
  'In a real fire you may have less than two minutes to get out. A plan you have practiced saves lives.':
      'Sa totoong sunog, baka wala pang dalawang minuto ang meron ka para makalabas. Nakapagliligtas ng buhay ang planong napraktis na.',
  'Map your exits': 'Alamin ang mga labasan',
  'Identify two ways out of every room — usually a door and a window.':
      'Alamin ang dalawang daan palabas sa bawat kuwarto — kadalasan isang pinto at isang bintana.',
  'Make sure windows and security grills open quickly from the inside.':
      'Siguraduhing mabilis mabuksan mula sa loob ang mga bintana at grills.',
  'Agree on a meeting point': 'Magkasundo sa isang tagpuan',
  'Pick a safe spot outside, like a specific post, tree, or neighbor\'s gate.':
      'Pumili ng ligtas na lugar sa labas, gaya ng isang poste, puno, o gate ng kapitbahay.',
  'Account for everyone there, and never go back inside for belongings.':
      'Doon bilangin kung kumpleto ang lahat, at huwag nang bumalik sa loob para sa mga gamit.',
  'Practice it': 'Praktisin ito',
  'Walk through the plan with your whole household, including children.':
      'Daanan ang plano kasama ang buong pamilya, pati ang mga bata.',
  'Practice once during the day and once at night.':
      'Magpraktis nang isang beses sa araw at isang beses sa gabi.',
  'Teach everyone the emergency hotline and how to trigger an SOS here.':
      'Ituro sa lahat ang emergency hotline at kung paano mag-SOS dito.',
  'If There\'s Smoke: Stay Low': 'Kapag May Usok: Yumuko',
  'Crawl beneath the smoke layer, cover your mouth, and feel doors before opening.':
      'Gumapang sa ilalim ng usok, takpan ang bibig, at kapain ang pinto bago buksan.',
  'Smoke and toxic gas — not flames — cause most fire deaths. Staying low keeps you in the cleaner air near the floor.':
      'Usok at nakalalasong gas — hindi apoy — ang sanhi ng karamihan ng namamatay sa sunog. Kapag nakayuko ka, mas malinis ang hanging nalalanghap mo malapit sa sahig.',
  'Move low and fast': 'Kumilos nang nakayuko at mabilis',
  'Crawl on your hands and knees, below the smoke layer.':
      'Gumapang gamit ang kamay at tuhod, sa ilalim ng usok.',
  'Cover your nose and mouth with a cloth, ideally a damp one.':
      'Takpan ang ilong at bibig ng tela, mas mabuti kung basa.',
  'Check before you open': 'Suriin bago buksan',
  'Feel doors with the back of your hand before opening them.':
      'Kapain ang pinto gamit ang likod ng kamay bago ito buksan.',
  'If a door is hot, use your second exit instead.':
      'Kung mainit ang pinto, gamitin na lang ang pangalawang labasan.',
  'Once you\'re out': 'Kapag nakalabas ka na',
  'Stay out and go straight to your meeting point.':
      'Huwag nang bumalik at dumiretso sa tagpuan.',
  'Call for help and report the location; do not re-enter.':
      'Tumawag ng tulong at sabihin ang lokasyon; huwag nang pumasok ulit.',
  'Treating Minor Burns': 'Paggamot sa Maliit na Paso',
  'Cool the burn under running water, cover it loosely, and avoid home remedies.':
      'Palamigin ang paso sa umaagos na tubig, takpan nang maluwag, at iwasan ang mga gamot-gamot sa bahay.',
  'Quick, correct first aid limits the damage from minor burns. Know what to do — and what to avoid.':
      'Ang mabilis at tamang first aid ay nakababawas sa pinsala ng maliit na paso. Alamin ang dapat gawin — at ang dapat iwasan.',
  'Cool the burn': 'Palamigin ang paso',
  'Hold the area under cool (not ice-cold) running water for 10–20 minutes.':
      'Itapat ang paso sa malamig (hindi nagyeyelong) umaagos na tubig nang 10–20 minuto.',
  'Remove rings or tight items near the burn before it swells.':
      'Tanggalin ang singsing o masisikip na gamit malapit sa paso bago ito mamaga.',
  'Protect it': 'Protektahan ito',
  'Cover loosely with a clean, non-stick cloth or sterile gauze.':
      'Takpan nang maluwag gamit ang malinis na telang hindi dumidikit o sterile na gasa.',
  'Do not apply toothpaste, butter, or ice — these worsen the injury.':
      'Huwag lagyan ng toothpaste, butter, o yelo — lalo nitong pinalalala ang sugat.',
  'When to seek help': 'Kailan hihingi ng tulong',
  'Get medical care for burns larger than your palm, or on the face, hands, or genitals.':
      'Magpatingin sa doktor kung mas malaki sa palad mo ang paso, o kung nasa mukha, kamay, o maselang bahagi ng katawan.',
  'Seek help for blistering, charred or white skin, or any burn on a child.':
      'Humingi ng tulong kung may paltos, sunog o pumuting balat, o kung bata ang napaso.',
  'Smoke Inhalation First Aid': 'First Aid sa Nakalanghap ng Usok',
  'Get to fresh air, watch for trouble breathing, and call for help on warning signs.':
      'Pumunta sa sariwang hangin, bantayan kung nahihirapang huminga, at tumawag ng tulong kapag may babalang palatandaan.',
  'Breathing in smoke can harm someone even without visible burns. Watch closely for the warning signs.':
      'Puwedeng mapinsala ng nalanghap na usok ang isang tao kahit walang nakikitang paso. Bantayang mabuti ang mga palatandaan.',
  'Get to fresh air': 'Pumunta sa sariwang hangin',
  'Move the person to fresh air immediately, keeping yourself safe.':
      'Dalhin agad sa sariwang hangin ang tao, nang hindi inilalagay sa panganib ang sarili.',
  'Loosen tight clothing around the neck and chest.':
      'Luwagan ang masisikip na damit sa leeg at dibdib.',
  'Watch for danger signs': 'Bantayan ang mga palatandaan ng panganib',
  'Coughing, hoarseness, soot around the nose or mouth, or trouble breathing.':
      'Pag-ubo, pamamaos, uling sa paligid ng ilong o bibig, o hirap sa paghinga.',
  'Confusion, dizziness, or bluish lips — call emergency services at once.':
      'Pagkalito, pagkahilo, o nangangasul na labi — tumawag agad sa emergency.',
  'While waiting for help': 'Habang naghihintay ng tulong',
  'Keep them calm and sitting upright to ease breathing.':
      'Panatilihin silang kalmado at nakaupo nang tuwid para gumaan ang paghinga.',
  'If you are trained and they stop breathing, begin CPR.':
      'Kung marunong ka at huminto sila sa paghinga, simulan ang CPR.',
  'Helping Someone in Shock': 'Pagtulong sa Taong Nasa Shock',
  'Lay them down, keep them warm, and get medical help — do not give food or drink.':
      'Pahigain sila, panatilihing mainit, at humingi ng tulong medikal — huwag silang bigyan ng pagkain o inumin.',
  'Shock can follow any serious injury or fright. Simple steps keep the person stable until help arrives.':
      'Puwedeng mangyari ang shock pagkatapos ng malubhang pinsala o matinding takot. Napapanatiling stable ng mga simpleng hakbang ang tao hanggang dumating ang tulong.',
  'Recognize it': 'Kilalanin ito',
  'Pale, cold, clammy skin; rapid breathing; weakness or confusion.':
      'Maputla, malamig, at malagkit na balat; mabilis na paghinga; panghihina o pagkalito.',
  'What to do': 'Ano ang gagawin',
  'Lay them down and raise their legs slightly if no injury prevents it.':
      'Pahigain sila at itaas nang kaunti ang mga binti kung walang pinsalang pumipigil dito.',
  'Keep them warm with a blanket and reassure them.':
      'Panatilihin silang mainit gamit ang kumot at palakasin ang loob nila.',
  'Do not give food or drink; call for medical help.':
      'Huwag silang bigyan ng pagkain o inumin; tumawag ng tulong medikal.',
  'Stop Bleeding from a Wound': 'Pigilan ang Pagdurugo ng Sugat',
  'Press firmly with a clean cloth, keep pressure on, and call for serious bleeding.':
      'Diinan gamit ang malinis na tela, huwag tigilan ang pagdiin, at tumawag ng tulong kung malala ang pagdurugo.',
  'Controlling heavy bleeding fast can save a life before responders arrive.':
      'Ang mabilis na pagpigil sa malakas na pagdurugo ay puwedeng makapagligtas ng buhay bago dumating ang mga responder.',
  'Apply pressure': 'Diinan',
  'Press firmly on the wound with a clean cloth or a gloved hand.':
      'Diinan nang mabuti ang sugat gamit ang malinis na tela o kamay na may guwantes.',
  'Keep steady pressure; do not lift it to check too often.':
      'Tuloy-tuloy na diinan; huwag madalas iangat para silipin.',
  'Keep it up': 'Ituloy lang',
  'Add more cloth on top if blood soaks through — don\'t remove the first layer.':
      'Patungan ng isa pang tela kapag tumagos ang dugo — huwag tanggalin ang unang tela.',
  'Raise the injured limb above heart level if possible.':
      'Itaas ang nasugatang braso o binti nang mas mataas sa puso kung kaya.',
  'Get help': 'Humingi ng tulong',
  'Call emergency services for deep, spurting, or non-stopping bleeding.':
      'Tumawag sa emergency kung malalim, bumubulwak, o hindi tumitigil ang pagdurugo.',
  'Keep the person warm and still until help arrives.':
      'Panatilihing mainit at hindi gumagalaw ang tao hanggang dumating ang tulong.',
  'All': 'Lahat',
  'Pasay': 'Pasay',
  'National emergency': 'Pambansang emergency',
  'Fire, medical or police — anywhere': 'Sunog, medikal o pulis — kahit saan',
  'The centralized, all-purpose emergency number in the Philippines. Call this for immediate police, fire, or medical response.':
      'Ang iisang emergency number para sa lahat ng emergency sa Pilipinas. Tawagan ito para sa agarang tulong ng pulis, bumbero, o medikal.',
  'Bureau of Fire · NCR': 'Bureau of Fire · NCR',
  'Direct line to the fire bureau': 'Direktang linya sa fire bureau',
  'Direct line for the National Capital Region fire bureau. While 911 works for fires, the BFP direct line can speed up response.':
      'Direktang linya ng fire bureau ng National Capital Region. Gumagana ang 911 para sa sunog, pero mas mapapabilis ng direktang linya ng BFP ang pagtugon.',
  'Philippine National Police': 'Philippine National Police',
  'Crimes in progress, public safety':
      'Krimeng nangyayari, kaligtasan ng publiko',
  'For crimes in progress, public-safety threats, and police assistance. The PNP Patrol hotline connects you to the nearest unit.':
      'Para sa krimeng nangyayari, banta sa kaligtasan ng publiko, at tulong ng pulis. Ikokonekta ka ng PNP Patrol hotline sa pinakamalapit na unit.',
  'Pasay City CDRRMO': 'Pasay City CDRRMO',
  'City rescue and disaster response':
      'Rescue at pagtugon sa sakuna ng lungsod',
  'Local Pasay City disaster risk reduction and emergency operations for incidents within the city.':
      'Ang disaster risk reduction at emergency operations ng Pasay City para sa mga insidente sa loob ng lungsod.',
  'Philippine Red Cross': 'Philippine Red Cross',
  'Ambulance, blood, disaster response':
      'Ambulansiya, dugo, pagtugon sa sakuna',
  'Ambulance, blood services, and disaster response. Call 143 for emergency assistance from the Red Cross.':
      'Ambulansiya, serbisyo sa dugo, at pagtugon sa sakuna. Tumawag sa 143 para sa emergency na tulong mula sa Red Cross.',
  'MMDA': 'MMDA',
  'Road crashes, flooding, clearing':
      'Banggaan sa kalsada, baha, paglilinis ng daan',
  'Call this for major traffic accidents, road emergencies, clearing operations, and flood-control assistance across Metro Manila.':
      'Tawagan ito para sa malalaking aksidente sa trapiko, emergency sa kalsada, paglilinis ng daan, at tulong sa baha sa buong Metro Manila.',
  'Philippine Coast Guard': 'Philippine Coast Guard',
  'Sea rescue, Manila Bay incidents':
      'Rescue sa dagat, insidente sa Manila Bay',
  'For maritime emergencies, ferry accidents, or coastal search and rescue operations.':
      'Para sa emergency sa dagat, aksidente ng barko, o search and rescue sa baybayin.',
  'NDRRMC': 'NDRRMC',
  'National disaster operations center':
      'Pambansang sentro ng operasyon sa sakuna',
  'National disaster operations center for typhoons, floods, earthquakes, and large-scale emergencies.':
      'Pambansang sentro ng operasyon sa sakuna para sa bagyo, baha, lindol, at malalaking emergency.',
  'How do I report an emergency?': 'Paano ako magre-report ng emergency?',
  'On the ALERT tab, press and hold the SOS button for 3 seconds. Take a photo of the scene, choose the responders you need (Fire, Police, Medical, Barangay), add optional notes, then tap REQUEST HELP NOW.':
      'Pindutin nang 3 segundo ang SOS button. Kunan ng litrato ang lugar, piliin ang mga responder na kailangan mo (Sunog, Pulis, Medikal, Barangay), magdagdag ng notes kung gusto, saka i-tap ang IPADALA ANG REPORT.',
  'What happens after I report?':
      'Ano ang mangyayari pagkatapos kong mag-report?',
  'Your report is localized into an incident area and sent to command for verification. Tap TRACK RESPONSE LIVE to follow the status — pending, verified, dispatched, en route, arrived, or resolved.':
      'Ilalagay ang report mo sa isang area ng insidente at ipapadala sa command para ma-verify. I-tap ang SUNDAN NANG LIVE para makita ang status — naghihintay, verified, ipinadala, papunta na, nandiyan na, o naayos na.',
  'Can I add more responders later?':
      'Puwede ba akong magdagdag ng responder mamaya?',
  'On the live tracking screen, tick the extra units under \'Do you need more help?\' and tap ADD MORE HELP. They\'re added to your existing incident — no new report and no second photo.':
      'Sa live tracking screen, i-tick ang dagdag na unit sa ilalim ng \'Kailangan pa ng tulong?\' at i-tap ang MAGDAGDAG NG TULONG. Idadagdag sila sa kasalukuyang insidente mo — walang bagong report at walang pangalawang litrato.',
  'What is my Trust Level?': 'Ano ang Trust Level ko?',
  'Verifying your email (+10%), phone (+40%), and National ID (+50%) raises your trust level, making your reports more credible to responders. Manage it in Profile → Verification.':
      'Tumataas ang trust level mo kapag na-verify ang email mo (+10%), phone (+40%), at National ID (+50%), kaya mas pinaniniwalaan ng mga responder ang mga report mo. Ayusin ito sa Profile → Verification.',
  'What are the \'fire near you\' alerts?':
      'Ano ang mga alertong \'may sunog malapit sa iyo\'?',
  'If someone reports a fire within 150 m of you, you receive a push alert. Tap it to confirm there is a fire (which files a corroborating report) or to ignore it. Manage alerts in Profile → Notifications.':
      'Kapag may nag-report ng sunog sa loob ng 150 m mula sa iyo, makakatanggap ka ng alerto. I-tap ito para kumpirmahing may sunog (magiging dagdag na report ito) o para i-ignore. Ayusin ang mga alerto sa Profile → Notifications.',
  'How do I find a safe area?': 'Paano ako makakahanap ng ligtas na lugar?',
  'On the live tracking screen the nearest evacuation site is shown. Tap SHOW ME THE WAY for in-app directions to it.':
      'Ipinapakita sa live tracking screen ang pinakamalapit na evacuation site. I-tap ang DAAN para sa direksiyon papunta roon sa loob ng app.',
  'Why do you need my camera and location?':
      'Bakit kailangan ninyo ang camera at location ko?',
  'A live photo and GPS confirm a real incident at your location and help responders reach you quickly. Your photos are stored privately.':
      'Pinapatunayan ng live na litrato at GPS na totoo ang insidente sa lokasyon mo at nakatutulong para mabilis kang marating ng mga responder. Pribadong nakatago ang mga litrato mo.',
  'One photo goes with every report': 'May isang litrato ang bawat report',
  'Answer when a report lands near you':
      'Sumagot kapag may report malapit sa iyo',
  'Photo of your ID': 'Litrato ng ID mo',
  'Step 1 of 3': 'Hakbang 1 sa 3',
  'Fit the whole card inside the frame. Avoid glare.':
      'Ipasok ang buong card sa loob ng frame. Iwasan ang silaw.',
  'Photo of your QR': 'Litrato ng QR mo',
  'Fit the whole QR code inside the frame. It is on the back of the card.':
      'Ipasok ang buong QR code sa loob ng frame. Nasa likod ito ng card.',
  'Live selfie': 'Live na selfie',
  'Step 3 of 3': 'Hakbang 3 sa 3',
  'Look straight at the camera. Remove glasses or a cap if you can.':
      'Tumingin nang diretso sa camera. Tanggalin ang salamin o sumbrero kung kaya.',
  'Fire Department': 'Bumbero',
  'HERCULES FIRE VOLUNTEER': 'HERCULES FIRE VOLUNTEER',
  'Police Department': 'Pulisya',
  'PASAY POLICE STATION': 'PASAY POLICE STATION',
  'Medical Support': 'Tulong medikal',
  'METRO PASAY HOSPITAL': 'METRO PASAY HOSPITAL',
  'Barangay Personnel': 'Tauhan ng barangay',
  'BARANGAY HALL': 'BARANGAY HALL',
  'Map': 'Mapa',
  'Hotlines': 'Hotlines',
  'Guides': 'Gabay',
  'Profile': 'Profile',
  'Incident': 'Insidente',
  'Hydrant': 'Hydrant',
  'Water': 'Tubig',
  'Cistern': 'Cistern',
  'Shelter': 'Shelter',
  'Risk zone': 'Mapanganib na lugar',
  'Unit': 'Unit',
  'January': 'Enero',
  'February': 'Pebrero',
  'March': 'Marso',
  'April': 'Abril',
  'May': 'Mayo',
  'June': 'Hunyo',
  'July': 'Hulyo',
  'August': 'Agosto',
  'September': 'Setyembre',
  'October': 'Oktubre',
  'November': 'Nobyembre',
  'December': 'Disyembre',
  'Release': 'Bitawan',
  '{distance} away': '{distance} ang layo',
  'SHELTER': 'SHELTER',
  'Open': 'Bukas',
  'Yes': 'Oo',
  'City': 'Lungsod',
  'Address': 'Address',
  'Capacity': 'Kapasidad',
  '{n} people': '{n} tao',
  'Distance': 'Layo',
  'Contact': 'Contact',
  'Notes': 'Notes',
  'Type': 'Uri',
  'Access': 'Daanan',
  'Accessible': 'Madadaanan',
  'Restricted': 'May limitasyon',
  'Accepted': 'Tinanggap na',
  'Now': 'Ngayon',
  'LIVE': 'LIVE',
  'Report': 'Report',
  'DETAILS': 'DETALYE',
  'TRACK': 'SUNDAN',
  'Add': 'Idagdag',
  'Incidents': 'Mga insidente',
  'Shelters': 'Mga shelter',
  'Risk zones': 'Mga mapanganib na lugar',
  'Cisterns': 'Mga cistern',
  'FIRE HYDRANT': 'FIRE HYDRANT',
  'RISK AREA': 'MAPANGANIB NA LUGAR',
  'BODY OF WATER': 'PINAGKUKUNAN NG TUBIG',
  'UNDERGROUND CISTERN': 'CISTERN SA ILALIM NG LUPA',
};
