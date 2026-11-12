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
  'Spread over 50 m': 'Kumalat nang higit 50 m',
  'Spread {m} m': 'Kumalat nang {m} m',
  'Confidence': 'Katiyakan',
  'Spatial agreement': 'Pagtutugma ng lokasyon',
  'Source credibility': 'Tiwala sa mga nag-report',
  'Reporters average {n}%': '{n}% ang average ng mga nag-report',
  'Progress': 'Progreso',
  'Step {n} of {of}': 'Hakbang {n} sa {of}',
  'You reported this — follow it': 'Ikaw ang nag-report nito — sundan ito',
  'You\'re {distance} away. A report joins this area only from within 50 m — if you can see something where you are, use SOS.':
      '{distance} ang layo mo. Sumasali lang ang report sa area na ito kung nasa loob ka ng 50 m — kung may nakikita ka kung nasaan ka, gamitin ang SOS.',
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
  'Asked within 100 m of the area': 'Tinanong sa loob ng 100 m mula sa area',
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
  'You sign in with your email. We will email you a link to confirm it.':
      'Email mo ang gamit sa pag-sign in. Magpapadala kami ng link sa email mo para makumpirma ito.',
  'Use email instead': 'Email na lang ang gamitin',
  'Forgot password?': 'Nakalimutan ang password?',
  'Sign in': 'Mag-sign in',
  'Still signing in. RepLiT can take up to a minute to wake after a quiet spell.':
      'Nagsa-sign in pa. Puwedeng umabot nang isang minuto bago gumising ang RepLiT kapag matagal itong hindi nagamit.',
  'Locked out or offline? Hotlines need no account and no internet.':
      'Hindi maka-sign in o offline? Hindi kailangan ng account o internet sa mga hotline.',
  'New to the app?': 'Bago ka sa app?',
  'Want to be an affiliate?': 'Gusto mo bang maging affiliate?',
  'Register here': 'Magparehistro dito',
  'Could not open the page. Visit {url}.':
      'Hindi mabuksan ang page. Pumunta sa {url}.',
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
  'When something is reported within 100 metres of you, RepLiT asks one question. Answering makes the report more certain.':
      'Kapag may na-report sa loob ng 100 metro mula sa iyo, isang tanong ang itatanong ng RepLiT. Kapag sumagot ka, mas tiyak ang report.',
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
  'RepLiT tells you about a fire within 100 m of where you are now. To know that while the app is closed, it needs your location "All the time". It sends it to RepLiT about every 15 minutes, and only for these alerts.':
      'Sinasabihan ka ng RepLiT tungkol sa sunog sa loob ng 100 m mula sa kinaroroonan mo ngayon. Para malaman iyon kahit sarado ang app, kailangan nito ang location mo nang "Palagi" ("All the time"). Ipinapadala ito sa RepLiT mga bawat 15 minuto, at para lang sa mga alertong ito.',
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
  'Fires reported within 100 m, and news on your reports':
      'Mga sunog na na-report sa loob ng 100 m, at balita sa mga report mo',
  'On. Fires within 100 m reach you even when RepLiT is closed.':
      'Naka-on. Aabot sa iyo ang mga sunog sa loob ng 100 m kahit sarado ang RepLiT.',
  'Allow location "All the time" so fires within 100 m reach you when RepLiT is closed.':
      'Payagan ang location nang "Palagi" ("All the time") para umabot sa iyo ang mga sunog sa loob ng 100 m kahit sarado ang RepLiT.',
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
  // WHAT'S NEXT, 1.1: the banner when a newer release is out.
  "There's a new update!": 'May bagong update!',
  'RepLiT {version} is ready to install.':
      'Handa nang i-install ang RepLiT {version}.',
  'UPDATE': 'I-UPDATE',
  'RepLiT {version} is out. Install it with Sideloadly, as before.':
      'Labas na ang RepLiT {version}. I-install ito sa Sideloadly, gaya ng dati.',
  // WHAT'S NEXT, 1.2: Change password, for residents and staff.
  'Change password': 'Palitan ang password',
  'CHANGE PASSWORD': 'PALITAN ANG PASSWORD',
  'Signs you out of your other phones': 'Masa-sign out ka sa iba mong phone',
  'Changing it signs you out of RepLiT on your other phones and browsers. This phone stays signed in.':
      'Kapag pinalitan ito, masa-sign out ka sa RepLiT sa iba mong phone at browser. Mananatiling naka-sign in ang phone na ito.',
  'Current password': 'Kasalukuyang password',
  'New password': 'Bagong password',
  'New password again': 'Bagong password ulit',
  'Show passwords': 'Ipakita ang mga password',
  'Enter your current password.': 'Ilagay ang kasalukuyang password mo.',
  'Use 8 to 128 characters for the new password.':
      'Gumamit ng 8 hanggang 128 na character para sa bagong password.',
  'The two new passwords are not the same.':
      'Hindi magkapareho ang dalawang bagong password.',
  'The new password is the same as the current one.':
      'Pareho ang bagong password sa kasalukuyan.',
  'That is not your current password.':
      'Hindi iyan ang kasalukuyang password mo.',
  'The password could not be changed. Try again.':
      'Hindi mapalitan ang password. Subukan ulit.',
  'Password changed. Other phones and browsers are signed out; this one stays signed in.':
      'Napalitan na ang password. Na-sign out na ang ibang phone at browser; naka-sign in pa rin ang phone na ito.',
  // The 6 November list: staff sign in at @replit.com, and their password
  // links go to their own email.
  "Enter the email you sign in with, or a staff account's personal email, and we'll send a reset link.":
      'Ilagay ang email na ginagamit mo sa pag-sign in, o ang personal email ng staff account, at padadalhan ka namin ng reset link.',
  'Enter an email like name@gmail.com.':
      'Maglagay ng email na tulad ng name@gmail.com.',
  'Use their own email: @replit.com addresses have no mailbox.':
      'Gamitin ang sarili nilang email: walang mailbox ang mga @replit.com na address.',
  'Use your own email: @replit.com addresses have no mailbox.':
      'Gamitin ang sarili mong email: walang mailbox ang mga @replit.com na address.',
  'Their personal email': 'Ang personal email nila',
  'We email them a link to confirm it and set their password. If they forget it, the reset link goes there too.':
      'Padadalhan namin sila ng link para kumpirmahin ito at itakda ang password nila. Kapag nakalimutan nila ito, doon din ipapadala ang reset link.',
  'Account ready': 'Handa na ang account',
  '{name} signs in with this address.':
      'Ito ang address na gagamitin ni {name} sa pag-sign in.',
  'Sign-in address': 'Address sa pag-sign in',
  // Resident sign-up (7 November): first and last name, the mobile
  // number optional.
  'Last name': 'Apelyido',
  'Please enter your first name.': 'Ilagay ang pangalan mo.',
  'Please enter your last name.': 'Ilagay ang apelyido mo.',
  'Mobile number (optional)': 'Mobile number (opsyonal)',
  'Checking it by SMS is coming soon.':
      'Malapit nang masuri ito sa pamamagitan ng SMS.',
  'We emailed {to} a link to confirm it and set their password. It works for three days.':
      'Nagpadala kami sa {to} ng link para kumpirmahin ito at itakda ang password nila. Gagana ito nang tatlong araw.',
  'That email is already confirmed.': 'Kumpirmado na ang email na iyan.',
  'We sent a link to {email}. Open it to confirm.':
      'Nagpadala kami ng link sa {email}. Buksan ito para kumpirmahin.',
  'The email could not be saved. Try again.':
      'Hindi ma-save ang email. Subukan ulit.',
  'Personal email': 'Personal email',
  'PERSONAL EMAIL': 'PERSONAL EMAIL',
  'Add one, so a forgotten password can be reset':
      'Magdagdag nito, para ma-reset ang password kapag nakalimutan',
  '{email} · confirmed': '{email} · kumpirmado',
  '{email} · open the link we sent':
      '{email} · buksan ang link na ipinadala namin',
  'Your sign-in at @replit.com has no mailbox. If you forget your password, the reset link comes to this email.':
      'Walang mailbox ang @replit.com na sign-in mo. Kapag nakalimutan mo ang password mo, sa email na ito ipapadala ang reset link.',
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
  'Grouped with reports within 50 m': 'Isinama sa mga report sa loob ng 50 m',
  'Within 50 m of an active area': 'Nasa loob ng 50 m ng isang aktibong area',
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
  'Neighbours within 100 m were alerted too':
      'Inalerto rin ang mga kapitbahay sa loob ng 100 m',
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
  'Could not load your account.': 'Hindi ma-load ang account mo.',
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
  'Coming soon': 'Malapit na',
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
  'Send the link': 'Ipadala ang link',
  // Sign-up's email link (7 November), in place of a texted code.
  'CHECK YOUR EMAIL': 'TINGNAN ANG EMAIL MO',
  'EMAIL CONFIRMED': 'KUMPIRMADO NA ANG EMAIL',
  'your email': 'ang email mo',
  "We'll email a link to {email}. Opening it confirms the address.":
      'Magpapadala kami ng link sa {email}. Kapag binuksan mo ito, kumpirmado na ang address.',
  'Sending a link to {email}…': 'Nagpapadala ng link sa {email}…',
  'We sent a link to {email}. Open it in Gmail and tap Verify my email. It works for 24 hours.':
      'Nagpadala kami ng link sa {email}. Buksan ito sa Gmail at i-tap ang Verify my email. Gumagana ito nang 24 oras.',
  'We sent a link to {email}. Open the email and tap Verify my email. It works for 24 hours.':
      'Nagpadala kami ng link sa {email}. Buksan ang email at i-tap ang Verify my email. Gumagana ito nang 24 oras.',
  '{email} is confirmed. Thank you!': 'Kumpirmado na ang {email}. Salamat!',
  'Open Gmail': 'Buksan ang Gmail',
  'Open your email': 'Buksan ang email mo',
  'Not in your inbox? Look in Spam or Promotions.':
      'Wala sa inbox mo? Tingnan sa Spam o Promotions.',
  'Send the link again': 'Ipadala ulit ang link',
  // Burner email addresses (backend v1.12.23).
  "Temporary email addresses can't be used. Use an email that will last, like your Gmail.":
      'Hindi puwede ang pansamantalang email. Gumamit ng email na pangmatagalan, gaya ng Gmail mo.',
  "Your email is from a temporary email service, so it can't be confirmed.":
      'Galing sa pansamantalang email service ang email mo, kaya hindi ito makukumpirma.',
  'That is all the links we can send today. Use the newest email we sent, or ask for another tomorrow.':
      'Iyan na ang lahat ng link na maipapadala namin ngayong araw. Gamitin ang pinakabagong email na ipinadala namin, o humingi ulit bukas.',
  'Could not send the email. Check your connection.':
      'Hindi maipadala ang email. Tingnan ang koneksyon mo.',
  'Open your email app and look for the email from RepLiT.':
      'Buksan ang email app mo at hanapin ang email mula sa RepLiT.',
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
  'If someone reports a fire within 100 m of you, you receive a push alert. Tap it to confirm there is a fire (which files a corroborating report) or to ignore it. Manage alerts in Profile → Notifications.':
      'Kapag may nag-report ng sunog sa loob ng 100 m mula sa iyo, makakatanggap ka ng alerto. I-tap ito para kumpirmahing may sunog (magiging dagdag na report ito) o para i-ignore. Ayusin ang mga alerto sa Profile → Notifications.',
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

  // WHAT'S NEXT, 1.3: the coordinator and responder screens, and the
  // older staff screens behind the menu. Staff terms stay in English as
  // the crews say them: Area, Coordinator, Responder, BFP, fire out, the
  // fire codes and the alarm levels.
  'Could not load the alarm requests. Check your signal.':
      'Hindi ma-load ang mga alarm request. Tingnan ang signal mo.',
  '{areaName} · now at {alarmWord}': '{areaName} · nasa {alarmWord} ngayon',
  'Set {alarmWord}?': 'Itakda sa {alarmWord}?',
  'Every organization on {areaName} sees the new level at once, and {askedBy} is told.':
      'Makikita agad ng bawat organisasyon sa {areaName} ang bagong antas, at sasabihan si {askedBy}.',
  'Set {alarmWord}': 'Itakda sa {alarmWord}',
  'Cancel': 'Kanselahin',
  '{areaName} is now at {alarmWord}.': 'Nasa {alarmWord} na ang {areaName}.',
  'Declined. {askedBy} is told {areaName} stays as it is.':
      'Tinanggihan. Sasabihan si {askedBy} na mananatili ang {areaName} sa dati.',
  'Could not send that. Check your signal.':
      'Hindi naipadala iyan. Tingnan ang signal mo.',
  'Could not open the Area. Check your signal.':
      'Hindi mabuksan ang Area. Tingnan ang signal mo.',
  'Alarm requests': 'Mga alarm request',
  'Fire Volunteer coordinators ask. Only BFP sets the alarm level.':
      'Humihiling ang mga Fire Volunteer coordinator. BFP lang ang nagtatakda ng antas ng alarma.',
  'Waiting': 'Naghihintay',
  'Answered': 'Nasagot',
  'Requests unavailable': 'Hindi available ang mga request',
  'Nothing answered yet': 'Wala pang nasagot',
  'Nothing waiting': 'Walang naghihintay',
  'Requests move here once BFP sets the level or declines, or the coordinator takes one back.':
      'Lumilipat dito ang mga request kapag itinakda ng BFP ang antas o tumanggi ito, o binawi ng coordinator.',
  "A request lands here, with the fire alert, when a Fire Volunteer coordinator asks BFP to raise an Area's alarm.":
      'Dumarating dito ang request, kasama ang fire alert, kapag hiniling ng isang Fire Volunteer coordinator sa BFP na itaas ang alarma ng isang Area.',
  '{word} · now at {alarmWord}': '{word} · nasa {alarmWord} ngayon',
  'Asked by {who}': 'Hiniling ni {who}',
  '{areaName} is already at {alarmWord}. Setting this would not raise it: decline it instead.':
      'Nasa {alarmWord} na ang {areaName}. Hindi ito tataas kapag itinakda ito: tanggihan na lang.',
  'Decline': 'Tanggihan',
  'Open {areaName}': 'Buksan ang {areaName}',
  ' by {answeredBy}': ' ni {answeredBy}',
  'Set{by}{when}.{notes}': 'Itinakda{by}{when}.{notes}',
  'Declined{by}{when}.{notes}': 'Tinanggihan{by}{when}.{notes}',
  'Taken back{when}.{notes}': 'Binawi{when}.{notes}',
  '{areaName} · {alarmWord} asked': '{areaName} · hiniling ang {alarmWord}',
  'Decline this request?': 'Tanggihan ang request na ito?',
  '{areaName} stays at {alarmWord}. {askedBy} is told, with your reason.':
      'Mananatili sa {alarmWord} ang {areaName}. Sasabihan si {askedBy}, kasama ang dahilan mo.',
  'Reason (optional)': 'Dahilan (opsyonal)',
  'Contained at 1st alarm': 'Napigilan sa 1st alarm',
  'Keep it waiting': 'Hayaang naghihintay',
  'Could not load {label}.': 'Hindi ma-load ang {label}.',
  'Dashboard': 'Dashboard',
  'Active Incidents': 'Mga aktibong insidente',
  'In progress now': 'Kasalukuyang nangyayari',
  'Units Deployed': 'Mga unit na naka-deploy',
  'On the way or on site': 'Papunta o nasa lugar na',
  'Alarm Requests': 'Mga alarm request',
  '{_pendingAlarms} pending • review & execute':
      '{_pendingAlarms} naghihintay • suriin at isagawa',
  'No pending requests': 'Walang naghihintay na request',
  'Live Map': 'Live map',
  'Real-time incidents across Pasay City':
      'Mga insidente ngayon sa buong Pasay City',
  'Updating live': 'Live na nag-a-update',
  '{value} reports • {value2} responding':
      '{value} report • {value2} rumeresponde',
  'Alarm: {alarm}': 'Alarma: {alarm}',
  'Open incident': 'Buksan ang insidente',
  'Could not load this Area. Check your signal.':
      'Hindi ma-load ang Area na ito. Tingnan ang signal mo.',
  'You are responding. Your location is shared while you go.':
      'Rumeresponde ka. Ibinabahagi ang lokasyon mo habang papunta ka.',
  'Accepted. Every agency asked for sees it acknowledged.':
      'Tinanggap. Makikita ng bawat ahensiyang hiningan na na-acknowledge ito.',
  'Could not accept. Check your connection.':
      'Hindi matanggap. Tingnan ang connection mo.',
  '{name} rejected. It has left the live feed.':
      'Tinanggihan ang {name}. Wala na ito sa live feed.',
  'Could not reject. Check your connection.':
      'Hindi matanggihan. Tingnan ang connection mo.',
  'Area': 'Area',
  '1 report': '1 report',
  '{bandWord} confidence': '{bandWord} na katiyakan',
  'The summary and the post-incident reports are for the teams that responded.':
      'Para sa mga team na rumesponde ang summary at ang mga post-incident report.',
  'No summary yet. The reports below are the full record.':
      'Wala pang summary. Nasa ibaba ang buong record: ang mga report.',
  'Reports': 'Mga report',
  '{n} · photos are staff-only': '{n} · para sa staff lang ang mga litrato',
  '{name} was merged': 'Pinagsama ang {name}',
  '{name} was rejected': 'Tinanggihan ang {name}',
  'Its reports joined a neighbouring Area. It has left the live feed.':
      'Napunta sa katabing Area ang mga report nito. Wala na ito sa live feed.',
  'Reason: {value}. It has left the live feed for everyone.':
      'Dahilan: {value}. Wala na ito sa live feed para sa lahat.',
  'none given': 'walang ibinigay',
  'Resident · {pct}% verified': 'Residente · {pct}% verified',
  'asked {asked}': 'hiningan ang {asked}',
  'Accept': 'Tanggapin',
  'Reject this area': 'Tanggihan ang Area na ito',
  'I am going': 'Papunta na ako',
  'Open live': 'Buksan ang live',
  'Accept {name}?': 'Tanggapin ang {name}?',
  'Accepting acknowledges it for {value}. Every agency the reporter asked for{value2} sees it as acknowledged.':
      'Kapag tinanggap, na-acknowledge ito para sa {value}. Makikita ng bawat ahensiyang hiningan ng nag-report{value2} na na-acknowledge ito.',
  'your organization': 'organisasyon mo',
  'Go to {name}?': 'Pumunta sa {name}?',
  'It is verified already. Going puts it on the way for the reporter and shares your location until you arrive.':
      'Verified na ito. Kapag pumunta ka, makikita ng nag-report na papunta na kayo, at ibabahagi ang lokasyon mo hanggang makarating ka.',
  'Accepting verifies the Area. Every agency the reporter asked for{value} sees it as verified.':
      'Kapag tinanggap, magiging verified ang Area. Makikita ng bawat ahensiyang hiningan ng nag-report{value} na verified ito.',
  'I am going too': 'Pupunta rin ako',
  'Dispatch a unit with this Accept':
      'Mag-dispatch ng unit kasabay ng pagtanggap na ito',
  'Last used first': 'Huling ginamit, una',
  "No unit is available in your team's register. You can still go; the report records the truck afterwards.":
      'Walang available na unit sa listahan ng team mo. Puwede ka pa ring pumunta; itatala ng report ang trak pagkatapos.',
  '{u} · last used': '{u} · huling ginamit',
  'Accept and go': 'Tanggapin at pumunta',
  'by 1 person': 'ng 1 tao',
  'by {people} people': 'ng {people} tao',
  '{name}, reported {value}{who}. {bandWord} confidence.':
      '{name}, na-report {value}{who}. {bandWord} na katiyakan.',
  'A rejected Area leaves the live feed for everyone and cannot be reopened or versioned.':
      'Mawawala sa live feed para sa lahat ang tinanggihang Area, at hindi na ito mabubuksan o mababago.',
  "Confirm · can't be undone": 'Kumpirmahin · hindi na maibabalik',
  'Reject {name}?': 'Tanggihan ang {name}?',
  'Only Fire Volunteer and BFP coordinators can reject. Admins cannot.':
      'Fire Volunteer at BFP coordinator lang ang puwedeng tumanggi. Hindi puwede ang mga Admin.',
  'Why': 'Bakit',
  'Reject {name}': 'Tanggihan ang {name}',
  'Keep it': 'Huwag tanggihan',
  'Could not load the fire codes.': 'Hindi ma-load ang mga fire code.',
  '{code_number} recorded at {clockText}. Every code press is kept in the audit log.':
      'Naitala ang {code_number} nang {clockText}. Itinatago sa audit log ang bawat pagpindot ng code.',
  'Could not record it. Check signal.':
      'Hindi ito naitala. Tingnan ang signal.',
  'No live incident': 'Walang live na insidente',
  'Fire codes': 'Mga fire code',
  'Pressing a code records an event on this incident. It does not change the Area status.':
      'Kapag pinindot ang isang code, may maitatalang pangyayari sa insidenteng ito. Hindi nito binabago ang status ng Area.',
  'Codes unavailable': 'Hindi available ang mga code',
  'Fire codes are pressed by Fire Volunteer and BFP Coordinators. You can see each one here.':
      'Ang mga Fire Volunteer at BFP Coordinator ang pumipindot ng mga fire code. Makikita mo rito ang bawat isa.',
  'Codes are pressed on a live incident. When an Area is under way, LIVE shows it and its codes work here.':
      'Sa live na insidente pinipindot ang mga code. Kapag may Area na nagaganap, ipinapakita ito sa LIVE at gumagana rito ang mga code nito.',
  'All codes': 'Lahat ng code',
  '1 code': '1 code',
  '{count} codes': '{count} code',
  'Code': 'Code',
  'Could not load the queue. Check your signal.':
      'Hindi ma-load ang queue. Tingnan ang signal mo.',
  'Live — the incident under way': 'Live — ang nagaganap na insidente',
  'Nothing under way': 'Walang nagaganap',
  'No incident is live': 'Walang live na insidente',
  'An Area shows here once it is accepted, with the units on their way and on scene. The queue has what is waiting on you.':
      'Lumalabas dito ang Area kapag natanggap na, kasama ang mga unit na papunta at nasa lugar. Nasa queue ang mga naghihintay sa iyo.',
  'Could not do that. Check your connection.':
      'Hindi iyan magawa. Tingnan ang connection mo.',
  'Marked on scene.': 'Minarkahang nasa lugar.',
  'Mark {name} fire out?': 'Markahan ang {name} na fire out?',
  'Everyone responding': 'Lahat ng rumeresponde',
  'Yes, mark fire out': 'Oo, markahang fire out',
  'Not yet, keep it live': 'Hindi pa, panatilihing live',
  'Could not mark fire out. Check your connection.':
      'Hindi mamarkahang fire out. Tingnan ang connection mo.',
  'Request taken back. BFP no longer sees it.':
      'Binawi ang request. Hindi na ito nakikita ng BFP.',
  'Asked BFP for {alarmWord}. You are told when they answer.':
      'Hiniling sa BFP ang {alarmWord}. Sasabihan ka kapag sumagot sila.',
  'Set by BFP · nothing waiting on you':
      'Itinakda ng BFP · walang naghihintay sa iyo',
  '1 request waiting on you': '1 request ang naghihintay sa iyo',
  '{n} requests waiting on you': '{n} request ang naghihintay sa iyo',
  'Set by BFP': 'Itinakda ng BFP',
  'You asked for {alarmWord} · waiting for BFP':
      'Hiniling mo ang {alarmWord} · hinihintay ang BFP',
  'BFP set {alarmWord}{when}, as you asked':
      'Itinakda ng BFP ang {alarmWord}{when}, gaya ng hiniling mo',
  'BFP declined {alarmWord}{when}{value}':
      'Tinanggihan ng BFP ang {alarmWord}{when}{value}',
  'Set by BFP · ask them to raise it':
      'Itinakda ng BFP · hilingin sa kanilang itaas ito',
  'Responder': 'Responder',
  'accepted {agoText}': 'tinanggap {agoText}',
  'NOBODY GOING YET': 'WALA PANG PUMUPUNTA',
  '1 UNIT RESPONDING': '1 UNIT ANG RUMERESPONDE',
  '{going} UNITS RESPONDING': '{going} UNIT ANG RUMERESPONDE',
  'Alarm level': 'Antas ng alarma',
  'Area details': 'Mga detalye ng Area',
  'Where it is, confidence, summary and reports':
      'Kung nasaan ito, katiyakan, summary at mga report',
  'Mark fire out': 'Markahang fire out',
  'Reject this Area': 'Tanggihan ang Area na ito',
  'You follow this Area here, and can get directions to it. Fire Volunteer and BFP coordinators and responders run the response: going, fire out and the report.':
      'Dito mo sinusundan ang Area na ito, at makakakuha ka ng direksiyon papunta rito. Ang mga Fire Volunteer at BFP coordinator at responder ang nagpapatakbo ng pagresponde: pagpunta, fire out at ang report.',
  'The Area is marked on scene': 'Minarkahang nasa lugar ang Area',
  'Within {_onSceneMetres} m of the fire':
      'Nasa loob ng {_onSceneMetres} m mula sa sunog',
  'No location yet': 'Wala pang lokasyon',
  '{formatDistance} away': '{formatDistance} ang layo',
  'last seen {agoText}': 'huling nakita {agoText}',
  'updates every 5 s': 'nag-a-update kada 5 s',
  '{name} · {crew} crew': '{name} · {crew} crew',
  'En route': 'Papunta',
  'Areas': 'Mga Area',
  'Fire stations': 'Mga fire station',
  'Monitoring Pasay · {value}': 'Binabantayan ang Pasay · {value}',
  'nothing on the ground': 'walang nasa lugar',
  '{live} on the ground': '{live} ang nasa lugar',
  'Live incidents': 'Mga live na insidente',
  '1 running now': '1 ang nagaganap ngayon',
  '{running} running now': '{running} ang nagaganap ngayon',
  'Nothing is running. New Areas appear here and on the map.':
      'Walang nagaganap. Lumalabas dito at sa mapa ang mga bagong Area.',
  '{reports} reports': '{reports} report',
  'An Area': 'Isang Area',
  'Area {d}': 'Area {d}',
  '{area} · Fire out, report filed': '{area} · Fire out, na-file ang report',
  'Merged into {area}': 'Pinagsama sa {area}',
  '{_area} · Merged into {area}': '{_area} · Pinagsama sa {area}',
  'Could not load your decisions.': 'Hindi ma-load ang mga desisyon mo.',
  'My decisions': 'Mga desisyon ko',
  'Decisions unavailable': 'Hindi available ang mga desisyon',
  'Recent': 'Kamakailan',
  '{count} shown': '{count} ang ipinapakita',
  'Nothing here yet. Each accept, reject, merge and fire out you make is listed as it happens.':
      'Wala pang laman dito. Nakalista rito ang bawat pagtanggap, pagtanggi, pagsasama at fire out na gagawin mo, habang nangyayari.',
  'Every decision is kept in the audit log with your role and agency at the time. It cannot be edited.':
      'Itinatago sa audit log ang bawat desisyon, kasama ang role at ahensiya mo noong panahong iyon. Hindi ito mae-edit.',
  '{_name} merged into {_name2}.': 'Pinagsama ang {_name} sa {_name2}.',
  'Kept as two Areas.': 'Pinanatiling dalawang Area.',
  'Could not decide. Check your signal.':
      'Hindi makapagpasya. Tingnan ang signal mo.',
  'Merge into {a}': 'Isama sa {a}',
  'Keep them separate': 'Panatilihing hiwalay',
  'Overlap': 'Overlap',
  'Overlap · {metres} m apart': 'Overlap · {metres} m ang layo',
  'Merge these Areas?': 'Pagsamahin ang mga Area na ito?',
  '{b} has grown into {a}.': 'Lumaki ang {b} hanggang sa {a}.',
  '{b} has grown to within {metres} m of {a}.':
      'Lumaki ang {b} hanggang {metres} m na lang mula sa {a}.',
  'Merging folds {b} into {a}. The smaller Area becomes "merged" and records what it joined. It cannot be split again.':
      'Kapag pinagsama, maisasama ang {b} sa {a}. Magiging "merged" ang mas maliit na Area at itatala kung saan ito sumama. Hindi na ito mapaghihiwalay ulit.',
  'The decision window has closed': 'Sarado na ang oras ng pagpapasya',
  'Decide within {_clock}': 'Magpasya sa loob ng {_clock}',
  'They stay as two Areas.': 'Mananatili silang dalawang Area.',
  'If nobody decides, they stay as two Areas.':
      'Kung walang magpapasya, mananatili silang dalawang Area.',
  'Alert volume': 'Lakas ng alerto',
  "How loud the alarm rings in the app, on top of your phone's notification volume. At 0% it stays quiet here only; the notification still shows.":
      'Kung gaano kalakas tumunog ang alarma sa app, dagdag sa notification volume ng phone mo. Sa 0%, tahimik lang ito rito; lalabas pa rin ang notification.',
  'Save': 'I-save',
  'Play it': 'Patugtugin',
  'You': 'Ikaw',
  'Coordinator · {value}': 'Coordinator · {value}',
  'You can accept and reject': 'Puwede kang tumanggap at tumanggi',
  'You can accept': 'Puwede kang tumanggap',
  'Any agency can accept. Only Fire Volunteer and BFP can reject.':
      'Puwedeng tumanggap ang kahit anong ahensiya. Fire Volunteer at BFP lang ang puwedeng tumanggi.',
  'Accepting acknowledges the Areas that ask for {asked}. Only Fire Volunteer and BFP can reject.':
      'Kapag tinanggap, na-acknowledge ang mga Area na humihingi ng {asked}. Fire Volunteer at BFP lang ang puwedeng tumanggi.',
  'Fire alert sound': 'Tunog ng fire alert',
  "Rings in the app when a new Area asks for {asked}. With the app closed, Android's {asked2} alerts channel rings it.":
      'Tumutunog sa app kapag may bagong Area na humihingi ng {asked}. Kapag sarado ang app, ang {asked2} alerts channel ng Android ang nagpapatunog nito.',
  'In the app only. At 0% it is quiet here.':
      'Sa app lang. Sa 0%, tahimik ito rito.',
  'Map rotation': 'Pag-ikot ng mapa',
  'Heading-up while moving, compass when still':
      'Sumusunod sa direksiyon habang gumagalaw, compass kapag nakatigil',
  'Hybrid': 'Hybrid',
  'Every accept, reject, merge and fire out you made':
      'Bawat pagtanggap, pagtanggi, pagsasama at fire out na ginawa mo',
  "Make and manage your responders' accounts":
      'Gumawa at mamahala ng mga account ng responder mo',
  'AI summaries': 'Mga AI summary',
  'What each fire your teams filed for came to':
      'Ang kinalabasan ng bawat sunog na pinag-file-an ng mga team mo',
  'Fire Volunteer asks to raise the alarm':
      'Mga hiling ng Fire Volunteer na itaas ang alarma',
  'Every notification sent to you': 'Bawat notification na ipinadala sa iyo',
  'Version {label} installed': 'Naka-install ang version {label}',
  'Coordinator · {responderAgencyLabel}':
      'Coordinator · {responderAgencyLabel}',
  'Accept an Area': 'Tumanggap ng Area',
  'Acknowledges it for your organization when it asks for your agency':
      'Na-acknowledge ito para sa organisasyon mo kapag humihingi ito ng ahensiya mo',
  'Merge or keep separate': 'Pagsamahin o panatilihing hiwalay',
  'When two Areas overlap': 'Kapag nag-overlap ang dalawang Area',
  'Follow an Area on LIVE and the map':
      'Sundan ang isang Area sa LIVE at sa mapa',
  'Its units and its alarm level':
      'Ang mga unit nito at ang antas ng alarma nito',
  'Route to an Area': 'Kumuha ng ruta papunta sa Area',
  'Directions, once it has been accepted': 'Direksiyon, kapag natanggap na ito',
  "Make your responders' accounts": 'Gumawa ng mga account ng responder mo',
  'Under Profile, Responders': 'Sa Profile, Responders',
  'Reject an Area': 'Tumanggi sa isang Area',
  'Fire Volunteer and BFP coordinators':
      'Mga Fire Volunteer at BFP coordinator',
  'Respond or mark fire out': 'Rumesponde o markahang fire out',
  'Fire Volunteer and BFP': 'Fire Volunteer at BFP',
  'Press fire codes': 'Pumindot ng mga fire code',
  'File the post-incident report': 'Mag-file ng post-incident report',
  'The responding fire team': 'Ang rumerespondeng fire team',
  'Change the alarm level': 'Baguhin ang antas ng alarma',
  'BFP coordinators only': 'Mga BFP coordinator lang',
  'Verifies it — and puts you on the way, on your unit, if you are going too':
      'Ginagawa itong verified — at papunta ka na, sakay ng unit mo, kung pupunta ka rin',
  'Fire Volunteer and BFP coordinators only':
      'Mga Fire Volunteer at BFP coordinator lang',
  'Your units stand down and stop sharing location':
      'Titigil ang mga unit mo at hindi na magbabahagi ng lokasyon',
  'Recorded as events on the incident':
      'Itinatala bilang mga pangyayari sa insidente',
  'Once per Area for your team, no draft':
      'Isang beses kada Area para sa team mo, walang draft',
  'Raise the alarm level': 'Itaas ang antas ng alarma',
  'From the alarm requests Fire Volunteer sends':
      'Mula sa mga alarm request na ipinapadala ng Fire Volunteer',
  'Ask BFP to raise the alarm': 'Hilingin sa BFP na itaas ang alarma',
  'From the alarm level on LIVE': 'Mula sa antas ng alarma sa LIVE',
  'Edit a filed report': 'Mag-edit ng na-file na report',
  'A post-incident report saves once':
      'Isang beses lang nase-save ang post-incident report',
  'Reopen a rejected Area': 'Buksan ulit ang tinanggihang Area',
  'It has left the live feed for good': 'Tuluyan na itong nawala sa live feed',
  'Queue': 'Queue',
  'To decide': 'Pagpapasyahan',
  'To file': 'Ifa-file',
  'Queue unavailable': 'Hindi available ang queue',
  '1 area': '1 Area',
  '{n} areas': '{n} Area',
  'Nothing to decide': 'Walang pagpapasyahan',
  'A new Area that asks for {_askedWord} lands here first.':
      'Dito unang dumarating ang bagong Area na humihingi ng {_askedWord}.',
  'Waiting on you': 'Naghihintay sa iyo',
  'Decide': 'Magpasya',
  'Any responding agency can accept. Only a Fire Volunteer or BFP coordinator can reject.':
      'Puwedeng tumanggap ang kahit anong rumerespondeng ahensiya. Fire Volunteer o BFP coordinator lang ang puwedeng tumanggi.',
  'These Areas asked for {_askedWord}. Accepting acknowledges them for {_team}. Only a Fire Volunteer or BFP Coordinator can reject.':
      'Humingi ng {_askedWord} ang mga Area na ito. Kapag tinanggap, na-acknowledge ang mga ito para sa {_team}. Fire Volunteer o BFP Coordinator lang ang puwedeng tumanggi.',
  '{areaName} asks for {alarmWord}': 'Humihingi ang {areaName} ng {alarmWord}',
  '{count} alarm requests waiting': '{count} alarm request ang naghihintay',
  '{who}. Only BFP sets the alarm level.':
      '{who}. BFP lang ang nagtatakda ng antas ng alarma.',
  'Newest: {areaName} asks for {alarmWord} · {who}.':
      'Pinakabago: humihingi ang {areaName} ng {alarmWord} · {who}.',
  'Answer': 'Sagutin',
  'Answer them': 'Sagutin ang mga ito',
  '{a} and {b} overlap': 'Nag-o-overlap ang {a} at {b}',
  '{value}. Merge them into one incident or keep them separate.':
      '{value}. Pagsamahin sila sa iisang insidente o panatilihing hiwalay.',
  'They are close': "Malapit sila sa isa't isa",
  'They are {metres} m apart': "{metres} m ang layo nila sa isa't isa",
  'Review': 'Suriin',
  'An Area you or another agency accepts shows here until the fire is out.':
      'Lumalabas dito ang Area na tinanggap mo o ng ibang ahensiya, hanggang mag-fire out.',
  'On the ground': 'Nasa lugar',
  'Accepted, nobody going yet': 'Tinanggap, wala pang pumupunta',
  'Only staff see who accepted. The public map shows status, confidence and report count — never who is responding.':
      'Staff lang ang nakakakita kung sino ang tumanggap. Ang pampublikong mapa ay nagpapakita ng status, katiyakan at bilang ng report — hindi kailanman kung sino ang rumeresponde.',
  'Accepted {clockText}': 'Tinanggap {clockText}',
  'Arrived {clockText}{value}': 'Dumating {clockText}{value}',
  '1 responding': '1 ang rumeresponde',
  '{going} responding': '{going} ang rumeresponde',
  'Nothing to file': 'Walang ifa-file',
  'When a fire your team went to is out, its report waits here.':
      'Kapag patay na ang sunog na pinuntahan ng team mo, dito maghihintay ang report nito.',
  'Reports to file': 'Mga report na ifa-file',
  'File report': 'Mag-file ng report',
  'An Area closes only after its post-incident report is filed. There is no draft — the form saves once, when it is complete.':
      'Nagsasara lang ang Area kapag na-file na ang post-incident report nito. Walang draft — isang beses lang nase-save ang form, kapag kumpleto na.',
  'Fire out {whenText} · {value}': 'Fire out {whenText} · {value}',
  'waiting {hours} h': 'naghihintay nang {hours} h',
  'ready to file': 'handa nang i-file',
  'Area {s}': 'Area {s}',
  'Report {number}': 'Report {number}',
  'Resident': 'Residente',
  '{pct}% verified{value}': '{pct}% verified{value}',
  'What they sent': 'Ang ipinadala nila',
  'No description': 'Walang paglalarawan',
  'Asked for {asked}': 'Humingi ng {asked}',
  'Where the phone was': 'Kung nasaan ang phone',
  'The photo and the phone disagree':
      'Hindi magkatugma ang litrato at ang phone',
  'The location in the photo is far from where the phone said it was. Weigh this report with care.':
      'Malayo ang lokasyon sa litrato sa sinabi ng phone na kinaroroonan nito. Timbangin nang mabuti ang report na ito.',
  'The photo carries no location of its own, so only the phone says where it was taken.':
      'Walang sariling lokasyon ang litrato, kaya ang phone lang ang nagsasabi kung saan ito kinunan.',
  'Duty': 'Duty',
  'Could not reach command': 'Hindi maabot ang command',
  'Your run': 'Ang run mo',
  'Open run': 'Buksan ang run',
  'Needs a unit': 'Kailangan ng unit',
  '1 Area': '1 Area',
  '{count} Areas': '{count} Area',
  'Pasay now': 'Pasay ngayon',
  'Location sharing is on': 'Naka-on ang pagbabahagi ng lokasyon',
  'Command sees where you are while you are on {value}. It stops when the Captain marks fire out.':
      'Nakikita ng command kung nasaan ka habang nasa {value} ka. Titigil ito kapag minarkahan ng Captain na fire out.',
  'your run': 'run mo',
  'Location sharing is off': 'Naka-off ang pagbabahagi ng lokasyon',
  'It starts when you tap I am going and stops when the Captain marks fire out.':
      'Magsisimula ito kapag pinindot mo ang Papunta na ako, at titigil kapag minarkahan ng Captain na fire out.',
  'No Area needs {unit}': 'Walang Area na nangangailangan ng {unit}',
  'When an Area asks for {agencyLabel} it arrives here with an alert sound. You can leave this screen.':
      'Kapag may Area na humingi ng {agencyLabel}, darating ito rito nang may alert sound. Puwede mong iwan ang screen na ito.',
  'Live now': 'Live ngayon',
  'To verify': 'Ive-verify',
  'Units out': 'Mga unit na nasa labas',
  'Standby': 'Standby',
  'Place': 'Lugar',
  'Around you': 'Sa paligid mo',
  'Within {aroundMetres} m': 'Sa loob ng {aroundMetres} m',
  'Hydrants, shelters and water near you are listed here once the phone knows where you are.':
      'Nakalista rito ang mga hydrant, evacuation center at tubig na malapit sa iyo kapag alam na ng phone kung nasaan ka.',
  'Nothing from the layers that are on is within {aroundMetres} m. Turn on Water or Cisterns for more.':
      'Walang nasa loob ng {aroundMetres} m mula sa mga naka-on na layer. I-on ang Water o Cisterns para sa iba pa.',
  '{formatDistance} from {name}': '{formatDistance} mula sa {name}',
  'Could not reach command. Check your signal.':
      'Hindi maabot ang command. Tingnan ang signal mo.',
  'That did not go through. Check your signal.':
      'Hindi iyon natuloy. Tingnan ang signal mo.',
  'You go as {_unit}. Your position is shared every 5 seconds until the Captain marks fire out.':
      'Pupunta ka bilang {_unit}. Ibabahagi ang posisyon mo kada 5 segundo hanggang markahan ng Captain na fire out.',
  'This Area is still Reported. Going now verifies it for every agency — Coordinators can still reject it later.':
      'Reported pa rin ang Area na ito. Kapag pumunta ka ngayon, magiging verified ito para sa bawat ahensiya — puwede pa rin itong tanggihan ng mga Coordinator mamaya.',
  'Cancel, go back': 'Kanselahin, bumalik',
  'You are going. Your location is shared while you go.':
      'Papunta ka na. Ibinabahagi ang lokasyon mo habang papunta ka.',
  'Verified. Go from here if you are going.':
      'Verified. Dito ka magsimula kung pupunta ka.',
  'Mark arrived?': 'Markahang dumating?',
  'Command and the other units see you on scene. It is the last status you set; the Captain marks fire out.':
      'Makikita ka ng command at ng ibang unit na nasa lugar ka na. Ito ang huling status na itatakda mo; ang Captain ang magmamarka ng fire out.',
  'Not yet': 'Hindi pa',
  '{label} is unavailable.': 'Hindi available ang {label}.',
  '{label} sent to command.': 'Naipadala sa command ang {label}.',
  'Could not send. Check your signal.':
      'Hindi maipadala. Tingnan ang signal mo.',
  'Could not send the request. Check your signal.':
      'Hindi maipadala ang request. Tingnan ang signal mo.',
  'Could not load the reports. Check your signal.':
      'Hindi ma-load ang mga report. Tingnan ang signal mo.',
  '{count} reports': '{count} report',
  'Photos are for staff only.': 'Para sa staff lang ang mga litrato.',
  'No reports could be read.': 'Walang report na mabasa.',
  'Could not load this Area': 'Hindi ma-load ang Area na ito',
  'Check your signal and try again.': 'Tingnan ang signal mo at subukan ulit.',
  '{formatDistance} from you': '{formatDistance} mula sa iyo',
  '1 resident': '1 residente',
  '{reports} residents': '{reports} residente',
  'First reported': 'Unang na-report',
  'Agencies asked': 'Mga hiningang ahensiya',
  'Acknowledged by': 'Na-acknowledge ng',
  'Route to the Area': 'Ruta papunta sa Area',
  'Directions only — going is I am going':
      'Direksiyon lang — ang pagpunta ay Papunta na ako',
  '{name} is over': 'Tapos na ang {name}',
  'A coordinator rejected it. Nobody goes.':
      'Tinanggihan ito ng isang coordinator. Walang pupunta.',
  'Its reports joined a neighbouring Area. Go from that one.':
      'Napunta sa katabing Area ang mga report nito. Doon ka magsimula.',
  'The fire is out. Nothing is asked of a unit that did not go.':
      'Patay na ang sunog. Walang hinihingi sa unit na hindi pumunta.',
  'Verify, without going': 'I-verify, nang hindi pumupunta',
  'Back to duty': 'Bumalik sa duty',
  'Rejected': 'Tinanggihan',
  'Stood down': 'Pinatigil',
  'Fire out at {clockText}.': 'Fire out nang {clockText}.',
  'ETA {_etaText}': 'ETA {_etaText}',
  'A coordinator rejected it while you were going. Your location sharing has stopped.':
      'Tinanggihan ito ng isang coordinator habang papunta ka. Tumigil na ang pagbabahagi ng lokasyon mo.',
  'Navigate': 'Mag-navigate',
  'What happened': 'Ang nangyari',
  'Your unit': 'Ang unit mo',
  'Codes to command': 'Mga code sa command',
  'Location sharing stopped': 'Tumigil ang pagbabahagi ng lokasyon',
  'Nothing more is asked of you for this Area.':
      'Wala nang hinihingi sa iyo para sa Area na ito.',
  'Your location is not going out': 'Hindi naipapadala ang lokasyon mo',
  'Allow RepLiT to use your location, so command can see you while you are on this run.':
      'Payagan ang RepLiT na gamitin ang lokasyon mo, para makita ka ng command habang nasa run na ito ka.',
  'Your location is still shared': 'Ibinabahagi pa rin ang lokasyon mo',
  'Your location is shared': 'Ibinabahagi ang lokasyon mo',
  'It stops on its own when the Captain marks fire out.':
      'Kusa itong titigil kapag minarkahan ng Captain na fire out.',
  'Every 5 seconds while you go. It stops when the Captain marks fire out.':
      'Kada 5 segundo habang papunta ka. Titigil ito kapag minarkahan ng Captain na fire out.',
  'Arrived': 'Dumating',
  'Arrived {clockText}': 'Dumating {clockText}',
  'Marked on its own when you reach the Area, or by you':
      'Kusang namamarkahan kapag naabot mo ang Area, o ikaw ang magmamarka',
  'The Area was marked arrived': 'Minarkahang dumating sa Area',
  'Fire out {clockText}': 'Fire out {clockText}',
  'The Captain calls it on scene': 'Ang Captain ang nagdedeklara nito sa lugar',
  'Stood down {clockText}': 'Pinatigil {clockText}',
  'Location sharing stops': 'Titigil ang pagbabahagi ng lokasyon',
  'Your location is no longer shared': 'Hindi na ibinabahagi ang lokasyon mo',
  'Post-incident report {clockText}': 'Post-incident report {clockText}',
  'Post-incident report': 'Post-incident report',
  'The Captain files it for the whole team — not yours to do':
      'Ang Captain ang nagfa-file nito para sa buong team — hindi ikaw ang gagawa',
  'Fire truck': 'Fire truck',
  'Driver {driver}': 'Driver {driver}',
  '1 on it': '1 ang sakay',
  '{count} on it': '{count} ang sakay',
  'Need water': 'Kailangan ng tubig',
  'More water supply to this Area': 'Dagdag na suplay ng tubig sa Area na ito',
  'FC-6': 'FC-6',
  'Need assistance': 'Kailangan ng tulong',
  'Backup responders to this Area': 'Mga backup na responder sa Area na ito',
  'FC-7': 'FC-7',
  'Escalate to BFP': 'I-escalate sa BFP',
  'Fire is out': 'Patay na ang sunog',
  'Tell command — the Captain marks it':
      'Sabihan ang command — ang Captain ang magmamarka nito',
  'FC-3': 'FC-3',
  'Responder · {agencyLabel}': 'Responder · {agencyLabel}',
  'Go to an Area': 'Pumunta sa isang Area',
  'I am going — verifies it if it is still Reported':
      'Papunta na ako — ginagawa itong verified kung Reported pa',
  'Verify an Area': 'Mag-verify ng Area',
  'Without going, while it is still Reported':
      'Nang hindi pumupunta, habang Reported pa ito',
  'Choose your route': 'Piliin ang ruta mo',
  'Up to three, all passable by a truck':
      'Hanggang tatlo, lahat madadaanan ng trak',
  'Or arrive on your own when you reach the Area':
      'O kusang dumating kapag naabot mo ang Area',
  'Share your position on a run': 'Ibahagi ang posisyon mo sa isang run',
  'Every 5 seconds, from going to fire out':
      'Kada 5 segundo, mula pagpunta hanggang fire out',
  'Call for water or help': 'Humingi ng tubig o tulong',
  'A code to command and every unit': 'Isang code sa command at sa bawat unit',
  'BFP sets the level': 'BFP ang nagtatakda ng antas',
  'Coordinators only': 'Mga coordinator lang',
  'The Captain on scene': 'Ang Captain sa lugar',
  'The Captain files for the whole team':
      'Ang Captain ang nagfa-file para sa buong team',
  'Responder — {agency}, {unit}': 'Responder — {agency}, {unit}',
  'Incident sounds': 'Mga tunog ng insidente',
  'A longer alert when an Area asks for your agency':
      'Mas mahabang alerto kapag may Area na humihingi ng ahensiya mo',
  'Voice directions': 'Direksiyon sa boses',
  'Spoken turn-by-turn on runs': 'Sinasabi ang bawat liko habang nasa run',
  'What you can do': 'Ang mga puwede mong gawin',
  'Your actions as a Responder': 'Ang mga gagawin mo bilang Responder',
  'RUN': 'RUN',
  'Run — the Area you are going to': 'Run — ang Area na pinupuntahan mo',
  'Bureau of Fire': 'Bureau of Fire',
  'Coast Guard': 'Coast Guard',
  'Response team': 'Response team',
  'ROUTED TO YOUR TEAM': 'IPINASA SA TEAM MO',
  'ROUTED TO {responderAgencyLabel}': 'IPINASA SA {responderAgencyLabel}',
  'ROUTED TO {join}': 'IPINASA SA {join}',
  'Admin': 'Admin',
  'Run': 'Run',
  'No run': 'Walang run',
  'When you tap I am going on an Area, your run is here: the way there, your crew, and what happens next.':
      'Kapag pinindot mo ang Papunta na ako sa isang Area, nandito ang run mo: ang daan papunta, ang crew mo, at ang susunod na mangyayari.',
  'Open duty': 'Buksan ang duty',
  'Summarized incident — {summaryDate}':
      'Na-summarize na insidente — {summaryDate}',
  'Could not load the summaries. Check your connection.':
      'Hindi ma-load ang mga summary. Tingnan ang connection mo.',
  "The AI writes a summary of each incident from the teams' Post-Incident Reports as soon as one is filed, and rewrites it when another team files. Open one to read it or download the report as a PDF.":
      'Gumagawa ang AI ng summary ng bawat insidente mula sa mga Post-Incident Report ng mga team sa sandaling may ma-file, at isinusulat itong muli kapag may ibang team na nag-file. Buksan ang isa para basahin ito o i-download ang report bilang PDF.',
  'No summaries yet': 'Wala pang summary',
  'A summary appears here once a team files its Post-Incident Report for an incident.':
      'Lalabas dito ang summary kapag nag-file ang isang team ng Post-Incident Report nito para sa isang insidente.',
  'Summarized incidents': 'Mga na-summarize na insidente',
  'Updating': 'Nag-a-update',
  'Writing': 'Isinusulat',
  'No summary': 'Walang summary',
  'Could not open the browser to download the PDF.':
      'Hindi mabuksan ang browser para i-download ang PDF.',
  'Could not reach the server. Try again.':
      'Hindi maabot ang server. Subukan ulit.',
  'AI summary': 'AI summary',
  'Download PDF': 'I-download ang PDF',
  'The AI is writing this summary now. It is usually ready within a minute — go back and the list will show it.':
      'Isinusulat ng AI ang summary na ito ngayon. Kadalasang handa ito sa loob ng isang minuto — bumalik ka at makikita ito sa listahan.',
  'Another team filed its report after this was written. The AI is rewriting the summary to include it.':
      'May ibang team na nag-file ng report nito pagkatapos maisulat ito. Isinusulat muli ng AI ang summary para maisama iyon.',
  "No summary has been written: the server has no AI key yet. The PDF still has every team's report.":
      'Walang naisulat na summary: wala pang AI key ang server. Nasa PDF pa rin ang report ng bawat team.',
  "Written by AI{value}{value2} from the teams' reports. Check it against them before relying on it.":
      'Isinulat ng AI{value}{value2} mula sa mga report ng mga team. Ikumpara ito sa mga iyon bago umasa rito.',
  ' on {summaryDate} at {summaryTime}':
      ' noong {summaryDate} nang {summaryTime}',
  "The PDF has the incident, its timeline, every team's Post-Incident Report and this summary. It is made when you download it, so it includes every report filed by then.":
      'Nasa PDF ang insidente, ang timeline nito, ang Post-Incident Report ng bawat team at ang summary na ito. Ginagawa ito kapag dina-download mo, kaya kasama ang bawat report na na-file hanggang noon.',
  'Could not load pending reports. Check your connection.':
      'Hindi ma-load ang mga naghihintay na report. Tingnan ang connection mo.',
  '{mins} min ago': '{mins} min na ang nakalipas',
  '{hrs}h {mins}m ago': '{hrs}h {mins}m na ang nakalipas',
  '{value}d ago': '{value} araw na ang nakalipas',
  'Pending reports': 'Mga naghihintay na report',
  'Fire out, and your team has not filed yet. Each team that responded files its own report, for everyone on it who went.':
      'Fire out na, at hindi pa nakakapag-file ang team mo. Bawat rumespondeng team ay nagfa-file ng sarili nitong report, para sa lahat ng miyembrong pumunta.',
  'Nothing owed. Every report is filed.':
      'Walang kulang. Na-file na ang bawat report.',
  'Fire out {_ago}': 'Fire out {_ago}',
  'File': 'I-file',
  'Fire out recorded': 'Naitala ang fire out',
  'File the report now?': 'I-file na ba ang report?',
  'The trucks, the driver, the crew and what came off the units — while the crew is fresh in mind. The Area closes when it is filed. It also waits in the queue, under To file.':
      'Ang mga trak, ang driver, ang crew at ang mga inilabas mula sa mga unit — habang sariwa pa sa isip ng crew. Magsasara ang Area kapag na-file ito. Naghihintay din ito sa queue, sa Ifa-file.',
  'File the report': 'I-file ang report',
  'Fire out. The report waits in the queue, under To file.':
      'Fire out. Naghihintay ang report sa queue, sa Ifa-file.',
  'Day the fire was out': 'Araw na namatay ang sunog',
  'Day of the incident': 'Araw ng insidente',
  'Time the fire was out': 'Oras na namatay ang sunog',
  'Time of the incident': 'Oras ng insidente',
  'That time has not happened yet.': 'Hindi pa dumarating ang oras na iyan.',
  'Truck': 'Trak',
  'Which vehicles went?': 'Aling mga sasakyan ang pumunta?',
  'Pick every unit that went to this fire.':
      'Piliin ang bawat unit na pumunta sa sunog na ito.',
  'Driver': 'Driver',
  'Who drove?': 'Sino ang nagmaneho?',
  'Whoever drove went, so they join the crew too.':
      'Pumunta ang nagmaneho, kaya kasama rin siya sa crew.',
  'Submit and close {_areaName}?': 'Ipasa at isara ang {_areaName}?',
  'The report saves once and cannot be edited. Filing it closes the Area.':
      'Isang beses lang nase-save ang report at hindi na ito mae-edit. Kapag na-file ito, magsasara ang Area.',
  'Submit and close Area': 'Ipasa at isara ang Area',
  'Could not file the report. Check your connection.':
      'Hindi ma-file ang report. Tingnan ang connection mo.',
  'Still needed: {join}': 'Kailangan pa: {join}',
  'Fire out {_clock}': 'Fire out {_clock}',
  'Fill it in one go. There is no draft — the Area closes when this saves.':
      'Punan ito nang isang upuan. Walang draft — magsasara ang Area kapag na-save ito.',
  'Outcome': 'Kinalabasan',
  'Fire attended': 'Sunog na pinuntahan',
  'False alarm': 'False alarm',
  'False alarm means the team arrived and found nothing — a prank, a wrong address, or already out. It must say what they found.':
      'Ang false alarm ay nangangahulugang dumating ang team at walang nakita — biro, maling address, o patay na. Dapat nitong sabihin kung ano ang nakita nila.',
  'Pick the units that went': 'Piliin ang mga unit na pumunta',
  'Which vehicles went': 'Aling mga sasakyan ang pumunta',
  'Which vehicle went': 'Aling sasakyan ang pumunta',
  'Pick the driver': 'Piliin ang driver',
  'Crew who went out': 'Crew na lumabas',
  '{count} selected': '{count} ang napili',
  'Your team has to load before you can pick.':
      'Kailangang ma-load muna ang team mo bago ka makapili.',
  '{name} — Driver': '{name} — Driver',
  'Equipment taken': 'Dinalang kagamitan',
  'Only what left the unit.': 'Ang mga inilabas lang mula sa unit.',
  'Required for a false alarm unless you picked what the team found. The AI summary turns this into the formal narrative.':
      'Kailangan para sa false alarm maliban kung pinili mo ang nakita ng team. Ginagawa itong pormal na salaysay ng AI summary.',
  'Optional. The AI summary turns this into the formal narrative.':
      'Opsyonal. Ginagawa itong pormal na salaysay ng AI summary.',
  'Times': 'Mga oras',
  '{label}. {value}. Change.': '{label}. {value}. Baguhin.',
  'Not set': 'Hindi pa nakatakda',
  'Tap to set': 'I-tap para itakda',
  'Change': 'Baguhin',
  'Could not load your team': 'Hindi ma-load ang team mo',
  'No team to pick from': 'Walang team na mapipili',
  'Could not load your team. Check your connection.':
      'Hindi ma-load ang team mo. Tingnan ang connection mo.',
  'Your account is not in an organization yet, so there is nobody to pick. Ask the admin to add you to your team.':
      'Wala pa sa isang organisasyon ang account mo, kaya walang mapipili. Hilingin sa admin na idagdag ka sa team mo.',
  'Back to queue': 'Bumalik sa queue',
  'Report filed': 'Na-file ang report',
  'Saved {clockText}': 'Na-save {clockText}',
  'Report saved': 'Na-save ang report',
  'Trucks, driver, crew, equipment and notes':
      'Mga trak, driver, crew, kagamitan at tala',
  'Area closed': 'Sarado na ang Area',
  'It has left the live feed for every role':
      'Wala na ito sa live feed para sa bawat role',
  'Closing it now': 'Isinasara na ngayon',
  'Formal narrative': 'Pormal na salaysay',
  'Written and attached': 'Naisulat at nakalakip',
  "Lit is writing it from your report and the residents' reports":
      'Isinusulat ito ni Lit mula sa report mo at sa mga report ng mga residente',
  'The server cannot write summaries right now. The report is complete without one.':
      'Hindi makapagsulat ng summary ang server ngayon. Kumpleto ang report kahit wala ito.',
  'You and Admin can read the narrative under AI summaries; nobody can edit it once it is attached.':
      'Mababasa mo at ng Admin ang salaysay sa AI summaries; walang makakapag-edit nito kapag nakalakip na.',
  'Writing…': 'Isinusulat…',
  'No summary. The report you filed is the full record.':
      'Walang summary. Ang report na na-file mo ang buong record.',
  'Summary: writing': 'Summary: isinusulat',
  'Summary': 'Summary',
  'Lit': 'Lit',
  'Pending Verify': 'Naghihintay ng verify',
  'Awaiting review': 'Naghihintay ng pagsusuri',
  'On the way to or on site': 'Papunta o nasa lugar na',
  'Units Standby': 'Mga unit na naka-standby',
  'Ready to respond': 'Handang rumesponde',
  'OPEN INCIDENT': 'BUKSAN ANG INSIDENTE',
  'Could not load incidents. Check your connection.':
      'Hindi ma-load ang mga insidente. Tingnan ang connection mo.',
  'No incidents to review right now.': 'Walang insidenteng susuriin ngayon.',
  'No reports in this area.': 'Walang report sa Area na ito.',
  'UNKNOWN REPORTER': 'HINDI KILALANG NAG-REPORT',
  '{label} broadcast to units.': 'Naipadala ang {label} sa mga unit.',
  'Could not broadcast. Check your connection.':
      'Hindi maipadala. Tingnan ang connection mo.',
  'Request alarm escalation': 'Humiling na itaas ang alarma',
  'Sent to BFP for review.': 'Naipadala sa BFP para suriin.',
  'Alarm escalation requested.': 'Naihiling na itaas ang alarma.',
  'Could not request escalation.': 'Hindi maihiling na itaas ang alarma.',
  'Action failed. Check your connection.':
      'Hindi natuloy. Tingnan ang connection mo.',
  'Reject incident': 'Tanggihan ang insidente',
  'Anyone responding will be told to stand down.':
      'Sasabihang tumigil ang sinumang rumeresponde.',
  'Reason (e.g. verified by mistake)':
      'Dahilan (hal. na-verify nang nagkamali)',
  'REJECT': 'TANGGIHAN',
  'Incident rejected. Anyone responding was stood down.':
      'Tinanggihan ang insidente. Pinatigil ang sinumang rumeresponde.',
  "Respond — I'm going": 'Rumesponde — papunta na ako',
  'Fire out?': 'Fire out na?',
  'Mark this incident resolved and stop the response.':
      'Markahang tapos ang insidenteng ito at itigil ang pagresponde.',
  'Could not resolve. Check your connection.':
      'Hindi matapos. Tingnan ang connection mo.',
  'NO LOCATION': 'WALANG LOKASYON',
  'Escalate alarm': 'Itaas ang alarma',
  'Broadcast a fire code to all responding units':
      'Magpadala ng fire code sa lahat ng rumerespondeng unit',
  'Need Water': 'Kailangan ng tubig',
  'Request additional water supply': 'Humingi ng dagdag na suplay ng tubig',
  'Need Assistance': 'Kailangan ng tulong',
  'Request backup responders': 'Humingi ng mga backup na responder',
  'Request alarm escalation to BFP': 'Humiling sa BFP na itaas ang alarma',
  'Locating incident…': 'Hinahanap ang insidente…',
  'Acknowledged by {verifier}': 'Na-acknowledge ni {verifier}',
  'ROUTE TO THE FIRE': 'RUTA PAPUNTA SA SUNOG',
  'ETA': 'ETA',
  'No active units on this incident.':
      'Walang aktibong unit sa insidenteng ito.',
  'Recorded in the Post-Incident Report': 'Nakatala sa Post-Incident Report',
  'Fire Truck': 'Fire truck',
  'Crew · {count}': 'Crew · {count}',
  'File Post-Incident Report': 'Mag-file ng Post-Incident Report',
  'INCIDENT CLOSED': 'SARADO NA ANG INSIDENTE',
  'INCIDENT REJECTED': 'TINANGGIHAN ANG INSIDENTE',
  'INCIDENT RESOLVED': 'TAPOS NA ANG INSIDENTE',
  'Reason (e.g. false report)': 'Dahilan (hal. maling report)',
  'Incident rejected.': 'Tinanggihan ang insidente.',
  'Verified. Respond if you are going.':
      'Verified. Rumesponde kung pupunta ka.',
  'Could not verify. Check your connection.':
      'Hindi ma-verify. Tingnan ang connection mo.',
  'Could not respond. Check your connection.':
      'Hindi makaresponde. Tingnan ang connection mo.',
  'Citizen report': 'Report ng residente',
  'DESCRIPTION': 'PAGLALARAWAN',
  'REPORTED BY': 'NAG-REPORT',
  'REPORTED': 'NA-REPORT',
  'COORDINATES': 'COORDINATES',
  'ADDRESS': 'ADDRESS',
  'VERIFIED BY': 'NAG-VERIFY',
  'NO PHOTO': 'WALANG LITRATO',
  'PHOTO UNAVAILABLE': 'HINDI AVAILABLE ANG LITRATO',
  'Reported fire photo': 'Litrato ng na-report na sunog',
  'Fire out. The Post-Incident Report is still owed — file it from Pending reports in the menu.':
      'Fire out na. Kulang pa ang Post-Incident Report — i-file ito mula sa Mga naghihintay na report sa menu.',
  'Closed — Post-Incident Report filed.':
      'Sarado na — na-file ang Post-Incident Report.',
  'This incident has been resolved.': 'Tapos na ang insidenteng ito.',
  'Rejected: {_rejectionReason}': 'Tinanggihan: {_rejectionReason}',
  'This incident was rejected.': 'Tinanggihan ang insidenteng ito.',
  'VERIFY': 'I-VERIFY',
  'You are responding. Open the incident from the map for the live response.':
      'Rumeresponde ka. Buksan ang insidente mula sa mapa para sa live na pagresponde.',
  "RESPOND — I'M GOING": 'RUMESPONDE — PAPUNTA NA AKO',
  'No actions available for this incident.':
      'Walang magagawa para sa insidenteng ito.',
  'Could not load your responders. Check your connection.':
      'Hindi ma-load ang mga responder mo. Tingnan ang connection mo.',
  'Reset password': 'I-reset ang password',
  'Deactivate account': 'I-deactivate ang account',
  'Reactivate account': 'I-reactivate ang account',
  'this responder': 'ang responder na ito',
  'Give {name} a new password?': 'Bigyan ng bagong password si {name}?',
  'Their current password stops working. You will see the new one once, to hand over.':
      'Hindi na gagana ang kasalukuyang password nila. Isang beses mo lang makikita ang bago, para ibigay.',
  'Deactivate {name}?': 'I-deactivate si {name}?',
  'They are on a response now; it will be released. They will not be able to sign in. Their history stays.':
      'Nasa pagresponde sila ngayon; aalisin sila roon. Hindi na sila makakapag-sign in. Mananatili ang kasaysayan nila.',
  'They will not be able to sign in. Their history stays, and you can reactivate the account later.':
      'Hindi na sila makakapag-sign in. Mananatili ang kasaysayan nila, at puwede mong i-reactivate ang account mamaya.',
  'Deactivate': 'I-deactivate',
  '{name} can no longer sign in.': 'Hindi na makakapag-sign in si {name}.',
  '{name} can sign in again with their last password.':
      'Makakapag-sign in ulit si {name} gamit ang huling password nila.',
  'New responder': 'Bagong responder',
  'Your responders': 'Ang mga responder mo',
  '{active} active': '{active} aktibo',
  'No responder accounts yet. Make one for each person on your team.':
      'Wala pang account ng responder. Gumawa ng isa para sa bawat tao sa team mo.',
  'Deactivated': 'Naka-deactivate',
  'On a run': 'Nasa run',
  'NEW RESPONDER': 'BAGONG RESPONDER',
  'First name': 'Pangalan',
  'Juan': 'Juan',
  'Surname': 'Apelyido',
  'Dela Cruz': 'Dela Cruz',
  'name@gmail.com': 'name@gmail.com',
  'Their sign-in': 'Ang sign-in nila',
  'Working it out…': 'Inaalam pa…',
  'Made from the first initial and surname':
      'Ginawa mula sa unang titik ng pangalan at sa apelyido',
  'Give {name} these to sign in with.':
      'Ibigay kay {name} ang mga ito para makapag-sign in.',
  'Give {name} this password to sign in with.':
      'Ibigay kay {name} ang password na ito para makapag-sign in.',
  'Copy {label}': 'Kopyahin ang {label}',
  '{label} copied.': 'Nakopya ang {label}.',
  'One report, no spread yet': 'Isang report, wala pang pagkalat',
  'Spread {value} m': 'Kalat {value} m',
  'Corroboration (×0.4)': 'Corroboration (×0.4)',
  '{reports} reports, full weight': '{reports} report, buong bigat',
  '{reports} of 10 reports': '{reports} sa 10 report',
  'Spatial agreement (×0.3)': 'Spatial agreement (×0.3)',
  'Source credibility (×0.3)': 'Source credibility (×0.3)',
  'Reporters average {value}%': 'Average ng mga nag-report {value}%',
  'Progress: {value}, step {value2} of {count}':
      'Progreso: {value}, hakbang {value2} sa {count}',
  'Lit is writing the summary. The reports below are the full record until it is ready.':
      'Isinusulat ni Lit ang summary. Ang mga report sa ibaba ang buong record hanggang handa ito.',
  'Location unknown': 'Hindi alam ang lokasyon',
  'under way': 'nagaganap',
  'not under way': 'hindi nagaganap',
  'The server enforces these rules. This screen only mirrors them.':
      'Ang server ang nagpapatupad ng mga panuntunang ito. Ipinapakita lang ito ng screen na ito.',
  'You can': 'Puwede mong',
  "You can't": 'Hindi mo puwedeng',
  'On-scene requests': 'Mga request mula sa lugar',
  'Locked': 'Naka-lock',
  'Unlocked · {label}': 'Naka-unlock · {label}',
  'Pick the fire type to unlock requests. Arrived is recorded already.':
      'Piliin ang uri ng sunog para ma-unlock ang mga request. Naitala na ang pagdating.',
  'You’re marked safe · {at}': 'Minarkahan kang ligtas · {at}',
  'Recorded for this fire. You won’t be alerted about it again.':
      'Naitala para sa sunog na ito. Hindi ka na aalertuhan tungkol dito.',
  'Help requested · {at}': 'Humingi ng tulong · {at}',
  'The responding Captain now sees your location and phone number. In danger right now? Call 911.':
      'Nakikita na ng rumerespondeng Captain ang lokasyon at numero ng phone mo. Nasa panganib ka ngayon? Tumawag sa 911.',
  'You’re not in the area': 'Wala ka sa lugar',
  'No more alerts or roll call for this Area.':
      'Wala nang alerto o roll call para sa Area na ito.',
  'Ignore': 'Huwag pansinin',
  'Are you safe?': 'Ligtas ka ba?',
  'Saving your answer…': 'Sine-save ang sagot mo…',
  'Safe': 'Ligtas',
  'Need help': 'Kailangan ng tulong',
  'Not in area': 'Wala sa lugar',
  'Need help · {raisedAt}': 'Kailangan ng tulong · {raisedAt}',
  'Seen {seenAt}': 'Nakita {seenAt}',
  'Resident needs help': 'Kailangan ng tulong ng residente',
  'Call': 'Tumawag',
  'Show on map': 'Ipakita sa mapa',
  'Visible to the responding Captain only — never to other residents.':
      'Nakikita lang ng rumerespondeng Captain — hindi kailanman ng ibang residente.',
  '{votes} residents': '{votes} residente',
  'Citizens report fire out': 'Iniulat ng mga residente na patay na ang sunog',
  '{residents} said the fire looks out':
      'Sinabi ng {residents} na mukhang patay na ang sunog',
  '{residents} {window}. Only you can mark fire out.':
      '{residents} {window}. Ikaw lang ang puwedeng magmarka ng fire out.',
  'Seen {seenAt}. Mark fire out once you have confirmed it on scene.':
      'Nakita {seenAt}. Markahang fire out kapag nakumpirma mo na ito sa lugar.',
  'Writing the CIAR': 'Isinusulat ang CIAR',
  'Lit is composing the formal report from your Post-Incident Report. Usually under 10 seconds.':
      'Binubuo ni Lit ang pormal na report mula sa Post-Incident Report mo. Kadalasang wala pang 10 segundo.',
  'The CIAR couldn’t be generated': 'Hindi nagawa ang CIAR',
  'Your Post-Incident Report is saved. Tell your Admin and quote the reference above.':
      'Naka-save ang Post-Incident Report mo. Sabihan ang Admin mo at ibigay ang reference sa itaas.',
  'CIAR attached': 'Nakalakip ang CIAR',
  'Locked {value}. Every agency on this Area can read it. It is never edited — corrections go on record.':
      'Naka-lock {value}. Mababasa ito ng bawat ahensiya sa Area na ito. Hindi ito kailanman ine-edit — itinatala ang mga pagwawasto.',
  'CIAR · {reference}': 'CIAR · {reference}',
  'View': 'Tingnan',
  '0% · not usable': '0% · hindi magagamit',
  '{pct} percent': '{pct} porsiyento',
  '0 percent, not usable': '0 porsiyento, hindi magagamit',
  '{p} percent': '{p} porsiyento',
  'Moves in 5% steps. 0% marks the source as not usable.':
      'Gumagalaw nang 5% kada hakbang. Ang 0% ay nagmamarka na hindi magagamit ang pinagkukunan.',
  'Urgency': 'Gaano kaapurahan',
  'Enter an estimate, like 2,000 litres.':
      'Maglagay ng tantiya, tulad ng 2,000 litro.',
  'Say what you need, like a 10 m ladder.':
      'Sabihin ang kailangan mo, tulad ng 10 m na hagdan.',
  'Pick the agency to ask.': 'Piliin ang ahensiyang hihingan.',
  'Pick a level.': 'Pumili ng antas.',
  'Pick how urgent it is.': 'Piliin kung gaano ito kaapurahan.',
  'Your request was not sent. Check your connection and send it again.':
      'Hindi naipadala ang request mo. Tingnan ang connection mo at ipadala ulit.',
  'Your Admin sees this at once and can ask other organizations for water.':
      'Makikita agad ito ng Admin mo at puwede siyang humingi ng tubig sa ibang organisasyon.',
  'Send request': 'Ipadala ang request',
  'Need equipment': 'Kailangan ng kagamitan',
  'Say exactly what you need. Your Admin passes it on.':
      'Sabihin nang eksakto ang kailangan mo. Ipapasa ito ng Admin mo.',
  'Need backup': 'Kailangan ng backup',
  'Pick the agency. Your Admin asks that agency’s Admins.':
      'Piliin ang ahensiya. Hihilingin ito ng Admin mo sa mga Admin ng ahensiyang iyon.',
  'Your Admin sends this to BFP Pasay. Only BFP sets the alarm level.':
      'Ipapadala ito ng Admin mo sa BFP Pasay. BFP lang ang nagtatakda ng antas ng alarma.',
  'Send escalation request': 'Ipadala ang request na itaas ang alarma',
  'Estimated amount': 'Tantiyang dami',
  'Rough is fine — gallons or litres.': 'Puwede ang tantiya — galon o litro.',
  'e.g. 2,000 litres': 'hal. 2,000 litro',
  'What do you need?': 'Ano ang kailangan mo?',
  'Free text for now. A picker may replace it later.':
      'Malayang teksto muna. Baka mapalitan ito ng pagpipilian mamaya.',
  'e.g. Extension ladder, 10 m. Two SCBA sets.':
      'hal. Extension ladder, 10 m. Dalawang SCBA set.',
  'Which agency?': 'Aling ahensiya?',
  'Propose a level': 'Magmungkahi ng antas',
  'Now: {currentLevel}': 'Ngayon: {currentLevel}',
  '{areaLabel} — {label} · step 2 of 2':
      '{areaLabel} — {label} · hakbang 2 sa 2',
  '{label} — which kind?': '{label} — anong uri?',
  'Pick the closest match. The Captain can correct it in the post-incident report.':
      'Piliin ang pinakamalapit. Puwede itong itama ng Captain sa post-incident report.',
  'Pick one to confirm': 'Pumili ng isa para kumpirmahin',
  'Confirm {label} — {_subtype}': 'Kumpirmahin ang {label} — {_subtype}',
  ' — arrived {arrivedAt}': ' — dumating {arrivedAt}',
  '{areaLabel}{arrived} · required': '{areaLabel}{arrived} · kailangan',
  'What’s burning?': 'Ano ang nasusunog?',
  'Pick the fire type. Requests for water, equipment, backup and escalation unlock once it is set.':
      'Piliin ang uri ng sunog. Mabubuksan ang mga request para sa tubig, kagamitan, backup at pagtaas ng alarma kapag naitakda na ito.',
  'Continue': 'Magpatuloy',
  'Confirm {label}': 'Kumpirmahin ang {label}',
  'Menu': 'Menu',
  'Staff': 'Staff',
  'Everyone responding stands down and stops sharing location. The Area moves to To file until you submit its post-incident report.':
      'Titigil ang lahat ng rumeresponde at hindi na magbabahagi ng lokasyon. Mapupunta ang Area sa Ifa-file hanggang maipasa mo ang post-incident report nito.',
  '{unit} stands down and stops sharing location. The Area moves to To file until you submit its post-incident report.':
      'Titigil ang {unit} at hindi na magbabahagi ng lokasyon. Mapupunta ang Area sa Ifa-file hanggang maipasa mo ang post-incident report nito.',
  '{units} stand down and stop sharing location. The Area moves to To file until you submit its post-incident report.':
      'Titigil ang {units} at hindi na magbabahagi ng lokasyon. Mapupunta ang Area sa Ifa-file hanggang maipasa mo ang post-incident report nito.',
  '1 Post-Incident Report to file': '1 Post-Incident Report ang ifa-file',
  '{n} Post-Incident Reports to file': '{n} Post-Incident Report ang ifa-file',
  'Your responders sign in with the accounts you make here. Each gets a @replit.com address, and a link to set the password goes to their own email.':
      'Nagsa-sign in ang mga responder mo gamit ang mga account na ginagawa mo rito. Bawat isa ay may @replit.com na address, at sa sarili nilang email ipinapadala ang link para itakda ang password.',
  'Hand these over in person. The password is shown only this once. You can give them a new one from this screen.':
      'Ibigay ang mga ito nang personal. Isang beses lang ipinapakita ang password. Puwede mo silang bigyan ng bago mula sa screen na ito.',
  'False alarm — no fire found': 'False alarm — walang nakitang sunog',
  'Duplicate of another Area': 'Kapareho ng ibang Area',
  'Not an emergency': 'Hindi emergency',
  'Prank or misuse': 'Biro o maling paggamit',
  'Codes': 'Mga code',
  'Merged': 'Pinagsama',
  'Kept separate': 'Pinanatiling hiwalay',
  'Acknowledged': 'Na-acknowledge',
  'Closed': 'Sarado',
  'Pick the fire type first': 'Piliin muna ang uri ng sunog',
  'Request to your Admin': 'Request sa Admin mo',
  'Say what you need': 'Sabihin ang kailangan mo',
  'Pick an agency': 'Pumili ng ahensiya',
  'Your Admin asks BFP': 'Ang Admin mo ang hihiling sa BFP',
  'I am safe': 'Ligtas ako',
  'Tell responders you are out of danger':
      'Sabihan ang mga responder na wala ka nang panganib',
  'I need help': 'Kailangan ko ng tulong',
  'The responding Captain sees where you are':
      'Makikita ng rumerespondeng Captain kung nasaan ka',
  'Not in the area': 'Wala sa lugar',
  'No more alerts for this Area': 'Wala nang alerto para sa Area na ito',
  'Water level': 'Antas ng tubig',
  'Unit not recorded': 'Hindi nakatala ang unit',
  'Coordinator': 'Coordinator',

  // v1.12.34: the loader, and Theme with System.
  'Loading': 'Naglo-load',
  'Theme': 'Tema',
  'THEME': 'TEMA',
  'System': 'Sistema',
  'Light': 'Maliwanag',
  'Dark': 'Madilim',
  'Follows your phone, light or dark':
      'Sumusunod sa phone mo, maliwanag man o madilim',
  'Light or dark screens': 'Maliwanag o madilim na screen',
  'Light or dark screens. The map keeps its own style.':
      'Maliwanag o madilim na screen. May sariling istilo ang mapa.',

  // v1.12.34: 18 and over, staff reports, what is burning.
  'You must be 18 or older to use RepLiT.':
      'Kailangang 18 taong gulang ka pataas para magamit ang RepLiT.',
  'Date of birth · 18 or older': 'Petsa ng kapanganakan · 18 pataas',
  'You report as staff — counted as fully trusted.':
      'Nag-uulat ka bilang staff — buong pinagkakatiwalaan ang report mo.',
  'You report as {who} — counted as fully trusted.':
      'Nag-uulat ka bilang {who} — buong pinagkakatiwalaan ang report mo.',
  'REPORT A FIRE': 'MAG-REPORT NG SUNOG',
  'Report a fire': 'Mag-report ng sunog',
  'Waiting for the unit on scene to say':
      'Hinihintay ang sasabihin ng unit na nasa lugar',
  'Required on scene. Pick the fire type.':
      'Kailangan pagdating sa lugar. Piliin ang uri ng sunog.',
  'Fire type': 'Uri ng sunog',
  'Fire type set: {label}.': 'Naitakda ang uri ng sunog: {label}.',
  'Could not save the fire type. Check your connection.':
      'Hindi na-save ang uri ng sunog. Tingnan ang koneksyon mo.',

  // v1.12.35: one phone per account.
  'OPENED ON ANOTHER PHONE': 'BINUKSAN SA IBANG PHONE',
  'Your RepLiT account was just signed in on another phone. One phone can use it at a time, so it has been signed out here.':
      'Kaka-sign in lang ng RepLiT account mo sa ibang phone. Isang phone lang ang puwedeng gumamit nito, kaya na-sign out ito rito.',
  'If that was not you, sign in again and change your password.':
      'Kung hindi ikaw iyon, mag-sign in ulit at palitan ang password mo.',

  // v1.12.36: a suspended or revoked organisation.
  "Your organization's RepLiT access is suspended. Ask the central hub (Barangay 76) why, and when it will be restored.":
      'Suspendido ang access ng organisasyon mo sa RepLiT. Tanungin ang central hub (Barangay 76) kung bakit, at kung kailan ito maibabalik.',
  'Your organization has been removed from RepLiT. Ask the central hub (Barangay 76) if you think this is a mistake.':
      'Inalis na ang organisasyon mo sa RepLiT. Tanungin ang central hub (Barangay 76) kung sa tingin mo ay pagkakamali ito.',
};
