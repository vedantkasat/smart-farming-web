import os, json, glob, random, numpy as np, tensorflow as tf
random.seed(42); np.random.seed(42); tf.random.set_seed(42)
ROOT='/home/claude/model/data/pv/raw/color'; OUT='/home/claude/model/out'; os.makedirs(OUT,exist_ok=True)
classes=sorted(os.listdir(ROOT)); print(len(classes),'classes')
files=[];labels=[]
for i,c in enumerate(classes):
    fs=sorted(glob.glob(f'{ROOT}/{c}/*')); files+=fs; labels+=[i]*len(fs)
idx=np.random.permutation(len(files)); files=[files[i] for i in idx]; labels=np.array(labels)[idx]
n=len(files); ntr=int(.70*n); nva=int(.15*n)
def load(p):
    img=tf.io.decode_image(tf.io.read_file(p),channels=3,expand_animations=False)
    img=tf.image.resize(img,(224,224)); return img
base=tf.keras.applications.MobileNetV2(input_shape=(224,224,3),include_top=False,weights='imagenet',pooling='avg')
def feats(fs,aug=False):
    ds=tf.data.Dataset.from_tensor_slices(fs).map(load,num_parallel_calls=4)
    if aug: ds=ds.map(lambda x: tf.image.random_flip_left_right(tf.image.random_brightness(x,25)))
    ds=ds.map(lambda x: tf.cast(x,tf.float32)/127.5-1.0).batch(64)
    return base.predict(ds,verbose=0)
if os.path.exists(OUT+'/feats.npz'):
    z=np.load(OUT+'/feats.npz'); Xtr,Xva,Xte=z['a'],z['b'],z['c']
else:
    Xtr=feats(files[:ntr]); Xva=feats(files[ntr:ntr+nva]); Xte=feats(files[ntr+nva:]); np.savez(OUT+'/feats.npz',a=Xtr,b=Xva,c=Xte)
ytr,yva,yte=labels[:ntr],labels[ntr:ntr+nva],labels[ntr+nva:]
print('features done',Xtr.shape)
head=tf.keras.Sequential([tf.keras.Input((1280,)),tf.keras.layers.Dropout(.3),tf.keras.layers.Dense(len(classes),activation='softmax')])
head.compile(optimizer=tf.keras.optimizers.Adam(1e-3),loss='sparse_categorical_crossentropy',metrics=['accuracy'])
head.fit(Xtr,ytr,validation_data=(Xva,yva),epochs=40,batch_size=64,verbose=2,callbacks=[tf.keras.callbacks.EarlyStopping(patience=5,restore_best_weights=True)])
pred=head.predict(Xte,verbose=0).argmax(1); acc=float((pred==yte).mean())
per={classes[i]:float((pred[yte==i]==i).mean()) for i in range(len(classes))}
conf=np.zeros((len(classes),)*2,int)
for a,b in zip(yte,pred): conf[a,b]+=1
print('TEST ACC',acc)
# full model
inp=tf.keras.Input((224,224,3)); x=tf.keras.layers.Rescaling(1/127.5,offset=-1)(inp); x=base(x); out=head.layers[-1](x)
full=tf.keras.Model(inp,out); full.save(f'{OUT}/leaf_model.keras')
json.dump({'classes':classes,'test_accuracy':acc,'n_images':n,'split':[ntr,nva,n-ntr-nva],'per_class_recall':per,'confusion':conf.tolist()},open(f'{OUT}/metrics.json','w'),indent=1)
json.dump(classes,open(f'{OUT}/labels.json','w'))
print('SAVED')
