import sys,os,h5py
out=sys.argv[1]
from tensorflowjs.converters import keras_h5_conversion as conv
mj,groups=conv.h5_merged_saved_model_to_tfjs_format(h5py.File('/tmp/m2.h5','r')) if hasattr(conv,'h5_merged_saved_model_to_tfjs_format') else (None,None)
os.makedirs(out,exist_ok=True)
conv.write_artifacts(mj,groups,out,quantization_dtype_map=(None if os.environ.get('NOQ') else {'float16':'*'}),weight_shard_size_bytes=4*1024*1024)
print('ok',os.listdir(out))
