import sys, os, json, numpy as np
os.environ['TF_USE_LEGACY_KERAS']='0'
import keras, tf_keras
src=sys.argv[1]; out=sys.argv[2]
k3=keras.models.load_model(src)
base3=[l for l in k3.layers if isinstance(l,keras.Model)][0]
dense3=k3.layers[-1]
inp=tf_keras.Input((224,224,3),name='image')
x=tf_keras.layers.Rescaling(1/127.5,offset=-1)(inp)
b2=tf_keras.applications.MobileNetV2(input_shape=(224,224,3),include_top=False,weights=None,pooling='avg')
x=b2(x); o=tf_keras.layers.Dense(dense3.units,activation='softmax')(x)
m2=tf_keras.Model(inp,o)
b2.set_weights(base3.get_weights()); m2.layers[-1].set_weights(dense3.get_weights())
# check equality
z=np.random.rand(2,224,224,3).astype('float32')*255
print('max diff',float(np.abs(k3.predict(z,verbose=0)-m2.predict(z,verbose=0)).max()))
m2.save('/tmp/m2.h5')
