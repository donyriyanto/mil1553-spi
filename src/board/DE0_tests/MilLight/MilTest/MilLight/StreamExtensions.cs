﻿using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MilLight
{
    public static class StreamExtensions
    {
        public static void WriteUInt16(this Stream stream, UInt16 value)
        {
            stream.WriteByte((byte)(value >> 8));
            stream.WriteByte((byte)(value & 0xFF));
        }

        public static UInt16 ReadUInt16(this Stream stream)
        {
            UInt16 result;
            byte[] buffer = new byte[2];

            stream.Read(buffer, 0, 2);

            result = (UInt16)(buffer[0] << 8);
            result += buffer[1];

            return result;
        }
    }
}
