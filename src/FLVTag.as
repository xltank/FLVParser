package
{
	import flash.utils.ByteArray;
	import flash.utils.IDataInput;
	import flash.utils.IDataOutput;

	
  	public class FLVTag
	{
		public static const TAG_TYPE_AUDIO:int = 8;
		public static const TAG_TYPE_VIDEO:int = 9;
		public static const TAG_TYPE_SCRIPTDATAOBJECT:int = 18;
		

		public static const TAG_HEADER_BYTE_COUNT:int = 11;
		public static const PREV_TAG_BYTE_COUNT:int = 4;
		
		
		
		public var bytes:ByteArray = null;
		
		
		private var _type:uint=0;
		public function get type():uint
		{
			return _type;
		}
		
		private var _dataSize:uint=0;
		public function get dataSize():uint
		{
			return _dataSize;  
		}
		
		private var _timestamp:uint=0;
		public function get timestamp():uint
		{
			return _timestamp;
		}
		public function set timestamp(value:uint):void
		{
			bytes[7] = (value >> 24) & 0xff;
			bytes[4] = (value >> 16) & 0xff;
			bytes[5] = (value >> 8) & 0xff;
			bytes[6] = (value) & 0xff;
			_timestamp = value;
		}
		
		private var _streamID:uint=0;
		
		
		public function FLVTag(bytes:ByteArray, type:uint, dataSize:uint, timestamp:uint, streamID:uint=0)
		{
			this.bytes = bytes;
			_type = type;
			_dataSize = dataSize;
			_timestamp = timestamp;
			_streamID = streamID;
		}
		
		
		/*public function write(output:IDataOutput):void
		{
			output.writeBytes(bytes, 0, TAG_HEADER_BYTE_COUNT + dataSize);
			output.writeUnsignedInt(TAG_HEADER_BYTE_COUNT + dataSize); 
		}*/
		
		
		
	}
}