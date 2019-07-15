//
// ASN1.cs: Abstract Syntax Notation 1 - micro-parser and generator
//
// Authors:
//    Sebastien Pouliot  <sebastien@ximian.com>
//    Jesper Pedersen  <jep@itplus.dk>
//
// (C) 2002, 2003 Motus Technologies Inc. (http://www.motus.com)
// Copyright (C) 2004 Novell, Inc (http://www.novell.com)
// (C) 2004 IT+ A/S (http://www.itplus.dk)
//
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// Modified by Nic Bedford (http://nicbedford.co.uk) to support multiple
// length tags.
//

import Foundation

    // References:
    // a.    ITU ASN.1 standards (free download)
    //    http://www.itu.int/ITU-T/studygroups/com17/languages/


class ASN1
{
    private (set) var tag : Data
    private (set) var value : Data
    private var elements = [ASN1]()

    convenience init( tag : UInt8, value : Data ) {
        self.init( tagData:Data( [tag] ), value: value )
    }

    init( tagData: Data, value: Data )
    {
        self.tag = tagData
        self.value = value

        if ((tag[0] & 0x20) == 0x20)
        {
            elements = ASN1.decodeElements( value )
        }

    }

    init?( data : Data )
    {
        let result = ASN1.decodeTLV( data, start: 0 )
        tag = result.0
        value = result.2

        if ((tag[0] & 0x20) == 0x20)
        {
            elements = ASN1.decodeElements( value )
        }
    }

    var length : Int { get { return value.count } }

    public func find( _ tag : UInt8 ) -> ASN1?
    {
        let tagData = Data( [tag] )
        return find( tagData )
    }

    private func find( _ tag : Data ) -> ASN1?
    {
        if( self.tag == tag)
        {
            return self
        }

        for asn1 in elements
        {
            if let result = asn1.find(tag) {
                return result
            }
        }
        return nil
    }

    // TLV : Tag - Length - Value
    static private func decodeTLV( _ data: Data, start: Int ) -> (Data, Int, Data, Int)
    {
        var tagLength = 1
        var pos = start

        // Check for multi byte tags
        if ((data[pos] & 0x1f) == 0x1f)
        {
            // Tag number is encoded in the following bytes as a sequence of seven bit bytes
            // The high bit of these bytes is used as a flag to indicate whether there's more tag available
            tagLength += 1
            while ((data[pos + tagLength - 1] & 0x80) == 0x80)
            {
                tagLength += 1
            }
        }

        let tag = data.subdata(in: pos ..< pos + tagLength )
        pos += tagLength

        var length = Int( data[pos] )
        pos += 1

        // Special case where L contains the Length of the Length + 0x80
        if ((length & 0x80) == 0x80)
        {
            let lengthLen = length & 0x7F
            length = 0

            precondition( lengthLen > 0 , "expecting a length" )
            for _ in 0 ..< lengthLen {
                length = length * 256 + Int( data[pos] )
                pos += 1
            }
        }

        let content = data.subdata(in: pos ..< pos + length )
        return (tag, length, content, pos)
    }

    // consume all elements in data
    static private func decodeElements( _ data : Data ) -> [ASN1] {
        var children = [ASN1]()
        var pos = 0

        while pos < data.count {
            let tlv = ASN1.decodeTLV( data, start: pos )

            let currentTag = tlv.0
            let currentValue = tlv.2

            pos = tlv.3 // value start

            // Sometimes we get trailing 0
            if (currentTag[0] == 0) {
                continue
            }

            let element = ASN1( tagData: currentTag, value: currentValue)
            children.append( element )
            pos += tlv.1 // value length
        }
        return children
    }


}

/*
extension ASN1 {
    // Unused:
    private func decodeTLV( asn1data : Data, start : Int) -> (UInt16, Int, Data)
    {
        var pos = start
        var tag : UInt16 = UInt16( asn1data[pos] )
        pos += 1

        // Check for 2 byte tags
        switch (tag)
        {
        case 0x5f,
             0x9f,
             0xbf:
            tag <<= 8;
            tag |= UInt16( asn1data[pos] )
            pos += 1
            break
        default:
            break
        }

        var length = Int( asn1data[pos] )
        pos += 1

        // Special case where L contains the Length of the Length + 0x80
        if ((length & 0x80) == 0x80)
        {
            let nLengthLen = length & 0x7F
            length = 0
            for _ in 0 ..< nLengthLen {
                length = length * 256 + Int( asn1data[pos] )
                pos += 1
            }
        }

        let content = asn1data.subdata( in: pos ..< pos + length )
        return (tag, length, content)
    }
}
 */

extension ASN1 : Sequence {
    typealias Iterator = Array<ASN1>.Iterator
    var count : Int { get { return elements.count } }

    __consuming func makeIterator() -> ASN1.Iterator {
        return elements.makeIterator()
    }
}


/*
    public var description : String
    {
        StringBuilder hexLine = new StringBuilder();

        // Add tag
        hexLine.AppendFormat("Tag: ");
        for (int i = 0; i < Tag.Length; i++)
        {
        hexLine.AppendFormat("{0} ", Tag[i].ToString("X2"));
        if ((i + 1) % 16 == 0)
        hexLine.AppendFormat(Environment.NewLine);
        }

        // Add length
        hexLine.AppendFormat("Length: {0} {1}", Value.Length, Environment.NewLine);

        // Add value
        hexLine.Append("Value: ");
        hexLine.Append(Environment.NewLine);
        for (int i = 0; i < Value.Length; i++)
        {
        hexLine.AppendFormat("{0}", Value[i].ToString("X2"));
        if ((i + 1) % 16 == 0)
        hexLine.AppendFormat(Environment.NewLine);
        }
        return hexLine.ToString();
    }

    public func SaveToFile( filename : String )
    {
        if (filename == null)
        throw new ArgumentNullException("filename");

        using (FileStream fs = File.OpenWrite(filename))
        {
        byte[] data = GetBytes();
        fs.Write(data, 0, data.Length);
        fs.Flush();
        fs.Close();
        }
    }
*/

 /*
 
 getBytes() -> [UInt8]
 {
 byte[] val = null;

 if (Count > 0)
 {
 int esize = 0;
 ArrayList al = new ArrayList();
 foreach (ASN1 a in elist)
 {
 byte[] item = a.GetBytes();
 al.Add(item);
 esize += item.Length;
 }
 val = new byte[esize];
 int pos = 0;
 for (int i = 0; i < elist.Count; i++)
 {
 byte[] item = (byte[])al[i];
 Buffer.BlockCopy(item, 0, val, pos, item.Length);
 pos += item.Length;
 }
 }
 else if (m_aValue != null)
 {
 val = m_aValue;
 }

 byte[] der;
 int nLengthLen = 0;

 if (val != null)
 {
 int nLength = val.Length;
 // Special for length > 127
 if (nLength > 127)
 {
 if (nLength <= Byte.MaxValue)
 {
 der = new byte[3 + nLength];
 Buffer.BlockCopy(val, 0, der, 3, nLength);
 nLengthLen = 0x81;
 der[2] = (byte)(nLength);
 }
 else if (nLength <= UInt16.MaxValue)
 {
 der = new byte[4 + nLength];
 Buffer.BlockCopy(val, 0, der, 4, nLength);
 nLengthLen = 0x82;
 der[2] = (byte)(nLength >> 8);
 der[3] = (byte)(nLength);
 }
 else if (nLength <= 0xFFFFFF)
 {
 // 24 bits
 der = new byte[5 + nLength];
 Buffer.BlockCopy(val, 0, der, 5, nLength);
 nLengthLen = 0x83;
 der[2] = (byte)(nLength >> 16);
 der[3] = (byte)(nLength >> 8);
 der[4] = (byte)(nLength);
 }
 else
 {
 // Max (Length is an integer) 32 bits
 der = new byte[6 + nLength];
 Buffer.BlockCopy(val, 0, der, 6, nLength);
 nLengthLen = 0x84;
 der[2] = (byte)(nLength >> 24);
 der[3] = (byte)(nLength >> 16);
 der[4] = (byte)(nLength >> 8);
 der[5] = (byte)(nLength);
 }
 }
 else
 {
 // Basic case (no encoding)
 der = new byte[m_aTag.Length + 1 + nLength];
 Buffer.BlockCopy(val, 0, der, m_aTag.Length + 1, nLength);
 nLengthLen = nLength;
 }
 if (m_aValue == null)
 m_aValue = val;
 }
 else
 der = new byte[m_aTag.Length + 1];

 Buffer.BlockCopy(m_aTag, 0, der, 0, m_aTag.Length);
 der[m_aTag.Length] = (byte)nLengthLen;

 return der;
 }
 */

