class BdDistrictData {
  const BdDistrictData({
    required this.name,
    required this.upazilas,
  });

  final String name;
  final List<String> upazilas;
}

class BdDivisionData {
  const BdDivisionData({
    required this.name,
    required this.districts,
  });

  final String name;
  final List<BdDistrictData> districts;
}

const List<BdDivisionData> bdDivisionsMockData = [
  BdDivisionData(
    name: 'Dhaka Division',
    districts: [
      BdDistrictData(name: 'Dhaka', upazilas: ['Dhamrai', 'Dohar', 'Keraniganj', 'Nawabganj', 'Savar']),
      BdDistrictData(name: 'Faridpur', upazilas: ['Alfadanga', 'Bhanga', 'Boalmari', 'Madhukhali', 'Nagarkanda']),
      BdDistrictData(name: 'Gazipur', upazilas: ['Gazipur Sadar', 'Kaliakair', 'Kaliganj', 'Kapasia', 'Sreepur']),
      BdDistrictData(name: 'Gopalganj', upazilas: ['Gopalganj Sadar', 'Kashiani', 'Kotalipara', 'Muksudpur', 'Tungipara']),
      BdDistrictData(name: 'Kishoreganj', upazilas: ['Austagram', 'Bajitpur', 'Bhairab', 'Hossainpur', 'Itna']),
      BdDistrictData(name: 'Madaripur', upazilas: ['Kalkini', 'Madaripur Sadar', 'Rajoir', 'Shibchar']),
      BdDistrictData(name: 'Manikganj', upazilas: ['Daulatpur', 'Ghior', 'Harirampur', 'Manikganj Sadar', 'Saturia']),
      BdDistrictData(name: 'Munshiganj', upazilas: ['Gazaria', 'Lohajang', 'Munshiganj Sadar', 'Sirajdikhan', 'Sreenagar']),
      BdDistrictData(name: 'Narayanganj', upazilas: ['Araihazar', 'Bandar', 'Rupganj', 'Sonargaon']),
      BdDistrictData(name: 'Narsingdi', upazilas: ['Belabo', 'Monohardi', 'Palash', 'Raipura', 'Shibpur']),
      BdDistrictData(name: 'Rajbari', upazilas: ['Baliakandi', 'Goalanda', 'Kalukhali', 'Pangsha', 'Rajbari Sadar']),
      BdDistrictData(name: 'Shariatpur', upazilas: ['Bhedarganj', 'Damudya', 'Gosairhat', 'Naria', 'Shariatpur Sadar']),
      BdDistrictData(name: 'Tangail', upazilas: ['Basail', 'Bhuapur', 'Delduar', 'Dhanbari', 'Ghatail', 'Nagarpur']),
    ],
  ),
  BdDivisionData(
    name: 'Chattogram Division',
    districts: [
      BdDistrictData(name: 'Chattogram', upazilas: ['Anwara', 'Banshkhali', 'Boalkhali', 'Fatikchhari', 'Hathazari', 'Mirsharai', 'Sitakunda']),
      BdDistrictData(name: "Cox's Bazar", upazilas: ['Chakaria', 'Kutubdia', 'Maheshkhali', 'Pekua', 'Ramu', 'Teknaf', 'Ukhia']),
      BdDistrictData(name: 'Cumilla', upazilas: ['Barura', 'Brahmanpara', 'Burichang', 'Chandina', 'Daudkandi', 'Debidwar', 'Homna', 'Muradnagar']),
      BdDistrictData(name: 'Feni', upazilas: ['Chhagalnaiya', 'Daganbhuiyan', 'Parshuram', 'Sonagazi', 'Fulgazi']),
      BdDistrictData(name: 'Brahmanbaria', upazilas: ['Akhaura', 'Ashuganj', 'Bancharampur', 'Kasba', 'Nabinagar', 'Sarail']),
      BdDistrictData(name: 'Chandpur', upazilas: ['Faridganj', 'Haimchar', 'Haziganj', 'Kachua', 'Matlab Uttar', 'Shahrasti']),
      BdDistrictData(name: 'Lakshmipur', upazilas: ['Raipur', 'Ramganj', 'Ramgati', 'Kamalnagar']),
      BdDistrictData(name: 'Noakhali', upazilas: ['Begumganj', 'Chatkhil', 'Companiganj', 'Hatiya', 'Kabirhat', 'Subarnachar']),
      BdDistrictData(name: 'Rangamati', upazilas: ['Bagaichhari', 'Barkal', 'Kawkhali', 'Belaichhari', 'Kaptai', 'Langadu']),
      BdDistrictData(name: 'Bandarban', upazilas: ['Ali Kadam', 'Lama', 'Naikhongchhari', 'Rowangchhari', 'Thanchi']),
      BdDistrictData(name: 'Khagrachhari', upazilas: ['Dighinala', 'Lakshmichhari', 'Mahalchhari', 'Manikchhari', 'Matiranga', 'Guimara']),
    ],
  ),
  BdDivisionData(
    name: 'Rajshahi Division',
    districts: [
      BdDistrictData(name: 'Rajshahi', upazilas: ['Bagha', 'Bagmara', 'Charghat', 'Durgapur', 'Godagari', 'Mohanpur', 'Puthia']),
      BdDistrictData(name: 'Bogura', upazilas: ['Adamdighi', 'Dhunat', 'Dhupchanchia', 'Gabtali', 'Kahaloo', 'Sariakandi', 'Shibganj']),
      BdDistrictData(name: 'Pabna', upazilas: ['Atgharia', 'Bera', 'Bhangura', 'Chatmohar', 'Ishwardi', 'Santhia']),
      BdDistrictData(name: 'Sirajganj', upazilas: ['Belkuchi', 'Chauhali', 'Kamarkhanda', 'Kazipur', 'Raiganj', 'Ullahpara']),
      BdDistrictData(name: 'Naogaon', upazilas: ['Atrai', 'Badalgachhi', 'Manda', 'Dhamoirhat', 'Mohadevpur', 'Patnitala', 'Sapahar']),
      BdDistrictData(name: 'Natore', upazilas: ['Bagatipara', 'Baraigram', 'Gurudaspur', 'Lalpur', 'Singra', 'Naldanga']),
      BdDistrictData(name: 'Joypurhat', upazilas: ['Akkelpur', 'Kalai', 'Khetlal', 'Panchbibi', 'Joypurhat Sadar']),
      BdDistrictData(name: 'Chapai Nawabganj', upazilas: ['Bholahat', 'Gomastapur', 'Nachole', 'Shibganj', 'Nawabganj Sadar']),
    ],
  ),
  BdDivisionData(
    name: 'Khulna Division',
    districts: [
      BdDistrictData(name: 'Khulna', upazilas: ['Batiaghata', 'Dacope', 'Dighalia', 'Dumuria', 'Koyra', 'Paikgachha', 'Rupsa']),
      BdDistrictData(name: 'Jashore', upazilas: ['Abhaynagar', 'Bagherpara', 'Chaugachha', 'Jhikargacha', 'Keshabpur', 'Monirampur']),
      BdDistrictData(name: 'Satkhira', upazilas: ['Assasuni', 'Debhata', 'Kalaroa', 'Kaliganj', 'Shyamnagar', 'Satkhira Sadar']),
      BdDistrictData(name: 'Bagerhat', upazilas: ['Chitalmari', 'Fakirhat', 'Kachua', 'Mollahat', 'Mongla', 'Rampal']),
      BdDistrictData(name: 'Kushtia', upazilas: ['Bheramara', 'Daulatpur', 'Khoksa', 'Kumarkhali', 'Mirpur', 'Kushtia Sadar']),
      BdDistrictData(name: 'Jhenaidah', upazilas: ['Harinakunda', 'Kaliganj', 'Kotchandpur', 'Maheshpur', 'Shailkupa']),
      BdDistrictData(name: 'Chuadanga', upazilas: ['Alamdanga', 'Damurhuda', 'Jibannagar', 'Chuadanga Sadar']),
      BdDistrictData(name: 'Magura', upazilas: ['Mohammadpur', 'Salikha', 'Sreepur', 'Magura Sadar']),
      BdDistrictData(name: 'Meherpur', upazilas: ['Gangni', 'Mujibnagar', 'Meherpur Sadar']),
      BdDistrictData(name: 'Narail', upazilas: ['Kalia', 'Lohagara', 'Narail Sadar']),
    ],
  ),
  BdDivisionData(
    name: 'Barishal Division',
    districts: [
      BdDistrictData(name: 'Barishal', upazilas: ['Agailjhara', 'Babuganj', 'Bakerganj', 'Banaripara', 'Gaurnadi', 'Mehendiganj']),
      BdDistrictData(name: 'Patuakhali', upazilas: ['Bauphal', 'Dashmina', 'Galachipa', 'Mirzaganj', 'Rangabali', 'Dumki']),
      BdDistrictData(name: 'Bhola', upazilas: ['Burhanuddin', 'Char Fasson', 'Daulatkhan', 'Lalmohan', 'Tazumuddin']),
      BdDistrictData(name: 'Pirojpur', upazilas: ['Bhandaria', 'Kawkhali', 'Mathbaria', 'Nazirpur', 'Nesarabad', 'Indurkani']),
      BdDistrictData(name: 'Barguna', upazilas: ['Amtali', 'Bamna', 'Betagi', 'Patharghata', 'Taltali']),
      BdDistrictData(name: 'Jhalokati', upazilas: ['Kathalia', 'Nalchity', 'Rajapur', 'Jhalokati Sadar']),
    ],
  ),
  BdDivisionData(
    name: 'Sylhet Division',
    districts: [
      BdDistrictData(name: 'Sylhet', upazilas: ['Balaganj', 'Beanibazar', 'Bishwanath', 'Companiganj', 'Gowainghat', 'Kanaighat', 'Zakiganj']),
      BdDistrictData(name: 'Habiganj', upazilas: ['Ajmiriganj', 'Bahubal', 'Baniachang', 'Chunarughat', 'Madhabpur', 'Nabiganj']),
      BdDistrictData(name: 'Moulvibazar', upazilas: ['Barlekha', 'Juri', 'Kamalganj', 'Kulaura', 'Rajnagar', 'Sreemangal']),
      BdDistrictData(name: 'Sunamganj', upazilas: ['Bishwambarpur', 'Chhatak', 'Derai', 'Dowarabazar', 'Jagannathpur', 'Tahirpur']),
    ],
  ),
  BdDivisionData(
    name: 'Rangpur Division',
    districts: [
      BdDistrictData(name: 'Rangpur', upazilas: ['Badarganj', 'Gangachara', 'Kaunia', 'Mithapukur', 'Pirgachha', 'Taraganj']),
      BdDistrictData(name: 'Dinajpur', upazilas: ['Birampur', 'Birganj', 'Bochaganj', 'Chirirbandar', 'Fulbari', 'Hakimpur']),
      BdDistrictData(name: 'Gaibandha', upazilas: ['Fulchhari', 'Gobindaganj', 'Palashbari', 'Sadullapur', 'Saghata', 'Sundarganj']),
      BdDistrictData(name: 'Kurigram', upazilas: ['Bhurungamari', 'Chilmari', 'Nageshwari', 'Phulbari', 'Rajarhat', 'Ulipur']),
      BdDistrictData(name: 'Nilphamari', upazilas: ['Dimla', 'Domar', 'Jaldhaka', 'Kishoreganj', 'Saidpur']),
      BdDistrictData(name: 'Panchagarh', upazilas: ['Atwari', 'Boda', 'Debiganj', 'Tetulia', 'Panchagarh Sadar']),
      BdDistrictData(name: 'Thakurgaon', upazilas: ['Baliadangi', 'Haripur', 'Pirganj', 'Ranisankail', 'Thakurgaon Sadar']),
      BdDistrictData(name: 'Lalmonirhat', upazilas: ['Aditmari', 'Hatibandha', 'Kaliganj', 'Patgram', 'Lalmonirhat Sadar']),
    ],
  ),
  BdDivisionData(
    name: 'Mymensingh Division',
    districts: [
      BdDistrictData(name: 'Mymensingh', upazilas: ['Bhaluka', 'Dhobaura', 'Fulbaria', 'Gafargaon', 'Haluaghat', 'Muktagachha']),
      BdDistrictData(name: 'Jamalpur', upazilas: ['Baksiganj', 'Dewanganj', 'Islampur', 'Madarganj', 'Sarishabari', 'Jamalpur Sadar']),
      BdDistrictData(name: 'Netrokona', upazilas: ['Atpara', 'Barhatta', 'Khaliajuri', 'Kalmakanda', 'Mohanganj', 'Purbadhala']),
      BdDistrictData(name: 'Sherpur', upazilas: ['Jhenaigati', 'Nakla', 'Nalitabari', 'Sreebardi', 'Sherpur Sadar']),
    ],
  ),
];
