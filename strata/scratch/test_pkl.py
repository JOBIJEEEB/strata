import pickle
import warnings
warnings.filterwarnings('ignore')

try:
    from sklearn.ensemble import RandomForestClassifier
except ImportError:
    pass

model = pickle.load(open('kaggle_and_strato_model_pruned.pkl', 'rb'))
print('Type:', type(model))

try:
    print('Classes:', model.classes_)
except Exception as e:
    print('No classes_:', e)

try:
    print('N_features:', model.n_features_in_)
except Exception as e:
    print('No n_features_in_:', e)

try:
    print('Feature names:', model.feature_names_in_)
except Exception as e:
    print('No feature_names_in_:', e)
