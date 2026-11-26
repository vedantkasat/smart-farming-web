/// General guidance only, no products or doses (report 7.4).
/// Keys match model/labels.json.
const diseases = <String, (String crop, String name, String advice)>{
  'Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot': (
    'Maize',
    'Grey leaf spot',
    'Fungal. Rotate crops, bury or remove infected residue, and choose tolerant hybrids next season.',
  ),
  'Corn_(maize)___Common_rust_': (
    'Maize',
    'Common rust',
    'Fungal. Usually managed with resistant hybrids; spraying is only worth it when infection is heavy early in the season.',
  ),
  'Corn_(maize)___Northern_Leaf_Blight': (
    'Maize',
    'Northern leaf blight',
    'Fungal. Rotate crops, manage residue and use resistant hybrids.',
  ),
  'Corn_(maize)___healthy': ('Maize', 'Healthy', ''),
  'Grape___Black_rot': ('Grape', 'Black rot', 'Fungal. Remove dried, shrivelled berries and infected leaves, and prune for airflow.'),
  'Grape___Esca_(Black_Measles)': (
    'Grape',
    'Esca (black measles)',
    'A trunk disease. Cut out infected wood and protect large pruning wounds.',
  ),
  'Grape___Leaf_blight_(Isariopsis_Leaf_Spot)': (
    'Grape',
    'Leaf blight (Isariopsis leaf spot)',
    'Fungal. Remove infected leaves and keep the canopy open.',
  ),
  'Grape___healthy': ('Grape', 'Healthy', ''),
  'Pepper,_bell___Bacterial_spot': (
    'Bell pepper',
    'Bacterial spot',
    'Bacterial. Use clean seed and seedlings, avoid overhead watering, and do not work among wet plants.',
  ),
  'Pepper,_bell___healthy': ('Bell pepper', 'Healthy', ''),
  'Potato___Early_blight': ('Potato', 'Early blight', 'Fungal. Remove infected lower leaves, rotate crops and keep the crop well fed.'),
  'Potato___Late_blight': (
    'Potato',
    'Late blight',
    'Spreads fast in cool, wet weather. Remove and destroy infected plants and get advice quickly.',
  ),
  'Potato___healthy': ('Potato', 'Healthy', ''),
  'Tomato___Bacterial_spot': (
    'Tomato',
    'Bacterial spot',
    'Bacterial. Use clean seedlings, avoid overhead watering and remove badly infected leaves.',
  ),
  'Tomato___Early_blight': ('Tomato', 'Early blight', 'Fungal. Remove infected lower leaves, mulch the soil and rotate crops.'),
  'Tomato___Late_blight': (
    'Tomato',
    'Late blight',
    'Spreads fast in cool, wet weather. Remove and destroy infected plants and get advice quickly.',
  ),
  'Tomato___Leaf_Mold': ('Tomato', 'Leaf mould', 'Fungal, favoured by high humidity. Improve ventilation and avoid wetting the leaves.'),
  'Tomato___Septoria_leaf_spot': (
    'Tomato',
    'Septoria leaf spot',
    'Fungal. Remove infected leaves, avoid wetting the leaves and rotate crops.',
  ),
  'Tomato___Spider_mites Two-spotted_spider_mite': (
    'Tomato',
    'Spider mites',
    'A pest, not a disease. Check under the leaves; a strong water spray and natural enemies help.',
  ),
  'Tomato___Target_Spot': ('Tomato', 'Target spot', 'Fungal. Remove crop debris and infected leaves and keep the canopy open.'),
  'Tomato___Tomato_Yellow_Leaf_Curl_Virus': (
    'Tomato',
    'Yellow leaf curl virus',
    'Spread by whiteflies; no cure. Remove infected plants, control whiteflies with yellow sticky traps and use resistant varieties.',
  ),
  'Tomato___Tomato_mosaic_virus': (
    'Tomato',
    'Mosaic virus',
    'Spread by touch and tools; no cure. Remove infected plants and wash hands and tools.',
  ),
  'Tomato___healthy': ('Tomato', 'Healthy', ''),
};

const leafCrops = ['Tomato', 'Potato', 'Maize', 'Grape', 'Bell pepper'];

/// Crop and name for a label, also for classes added by retraining with --all-classes.
(String, String, String) describe(String label) {
  final d = diseases[label];
  if (d != null) return d;
  final parts = label.split('___');
  final crop = parts.first.replaceAll('_', ' ').trim();
  final name = parts.length > 1 ? parts[1].replaceAll('_', ' ').trim() : label;
  return (crop, name.toLowerCase() == 'healthy' ? 'Healthy' : name, '');
}
