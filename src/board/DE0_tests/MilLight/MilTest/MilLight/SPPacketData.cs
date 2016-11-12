﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MilLight
{
    public class SPPacketData : ExpirableObject, ISPPacket
    {
        public override bool IsActual
        {
            get { return base.IsActual && !Data.Exists(a => !((ExpirableObject)a).IsActual); }
        }

        private byte addr;
        public byte Addr
        {
            get
            {
                Actualize();
                return addr;
            }
            set
            {
                addr = value;
                Expire();
            }
        }

        private byte command;
        public SPCommand Command
        {
            get
            {
                Actualize();
                return (SPCommand)command;
            }
            set
            {
                command = (byte)value;
                Expire();
            }
        }

        private List<IMilPacket> data = new List<IMilPacket>();
        public List<IMilPacket> Data
        {
            get
            {
                Actualize();
                return data;
            }
            set
            {
                data = value;
                Expire();
            }
        }

        public UInt16 PackNum { get; set; }

        private UInt16 dataSize;
        public UInt16 DataSize
        {
            get
            {
                Actualize();
                return dataSize;
            }
        }

        private UInt16 checkSum;
        public UInt16 CheckSum
        {
            get
            {
                Actualize();
                return checkSum;
            }
        }

        protected override void Actualization()
        {
            dataSize = (UInt16)(data.Sum(a => a.Size));
            checkSum = (UInt16)((addr << 8) + (dataSize >> 8));
            checkSum += (UInt16)((dataSize << 8) + ((byte)command));
            checkSum += (UInt16)(data.Sum(a => a.CheckSum));
        }
    }
}
