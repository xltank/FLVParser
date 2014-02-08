package
{
	import flash.utils.ByteArray;
	import flash.utils.IDataInput;

	public class FLVTagFactory
	{
		public function FLVTagFactory()
		{
		}
		
		
		public static function getTag(input:ByteArray):FLVTag
		{
			if (input.bytesAvailable < FLVTag.TAG_HEADER_BYTE_COUNT)
			{
//				throw new Error("FLVTag.readHeader() input too short");
				trace("Tag Header incomplete!");
				return null;
			}
			
			var type:uint = input.readUnsignedByte() & 0x1F;
			var dataSize:uint = (input.readUnsignedShort() << 8) + input.readUnsignedByte();
			var time:uint = input.readUnsignedInt();
			var timestamp:uint = ((time & 0xFF)<<24) + time >> 8;
			var streamID:uint = input.readUnsignedShort() << 8 + input.readUnsignedByte();
			
			if(dataSize + FLVTag.TAG_HEADER_BYTE_COUNT > input.bytesAvailable) // timestamp, streamID.
			{
				input.position -= FLVTag.TAG_HEADER_BYTE_COUNT;
				return null;
			}
			else
			{
				input.position -= FLVTag.TAG_HEADER_BYTE_COUNT;
				var bytes:ByteArray = new ByteArray();
				// including the following "PreviousTagSize".
				input.readBytes(bytes, 0, dataSize + FLVTag.TAG_HEADER_BYTE_COUNT + FLVTag.PREV_TAG_BYTE_COUNT);
//				trace("tag length", bytes.length);
				return new FLVTag(bytes, type, dataSize, timestamp, streamID);
			}
			
			return null;
		}
		
	}
}