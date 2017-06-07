function [] = readSignalStrengthMessage(s)

% required values
SYNC_1 = hex2dec('A0');
SYNC_2 = hex2dec('B1');
MSG_LEN = 16;

PARSE_SYNC_1 = 1;
PARSE_SYNC_2 = 2;
PARSE_MSG = 3;

% for testing do this for 5 messages
N = 0;

state = PARSE_SYNC_1;
msg = uint8(zeros(1, 16));
msgIndex = 1;

allValues = zeros(1, 100);
avIndex = 1;

while (N < 50)
    
    c = fread(s, 1, 'uint8');
    allValues(avIndex) = c;
    avIndex = avIndex + 1;
    
    switch (state)
        case PARSE_SYNC_1
            
            if (c == SYNC_1)
                state = PARSE_SYNC_2;
            end
            
        case PARSE_SYNC_2
            
            if (c == SYNC_2)
                state = PARSE_MSG;
                msgIndex = 1;
            end
            
        case PARSE_MSG
            msg(msgIndex) = c;
            msgIndex = msgIndex + 1;
            
            if (msgIndex > MSG_LEN)
                state = PARSE_SYNC_1;
                N = N + 1;
                
                % DEBUG - output the parsed data
                parsed.timestamp = typecast(msg(1:4), 'uint32');
                parsed.signalStrength = typecast(msg(5:8), 'single');
                parsed.azimuth = typecast(msg(9:12), 'single');
                parsed.elevation = typecast(msg(13:16), 'single');
                parsed
            end
    end
    
end