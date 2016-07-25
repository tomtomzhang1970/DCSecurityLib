// OpenSSLRSAWrapper.m
// Version 3.0
//
// Copyright (c) 2012 scott ban ( http://github.com/reference )
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "OpenSSLRSAWrapper.h"
#import "Base64.h"

#define OpenSSLRSAPublicKeyFile [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"private.pem"]

#define OpenSSLRSAPrivateKeyFile [[NSBundle mainBundle] pathForResource:@"rsa" ofType:@"pem"]

#define OpenSSLRSAPrivateKeyFile2 [[NSBundle mainBundle] pathForResource:@"private_key1" ofType:@"pem"]

#define OpenSSLRSAPrivateKeyFile1 [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@".private_key.rce"]

@implementation OpenSSLRSAWrapper
@synthesize publicKeyBase64,privateKeyBase64;

#pragma mark - getter

// Helper function for ASN.1 encoding

size_t encodeLength(unsigned char * buf, size_t length) {
    
    // encode length in ASN.1 DER format
    if (length < 128) {
        buf[0] = length;
        return 1;
    }
    
    size_t i = (length / 256) + 1;
    buf[0] = i + 0x80;
    for (size_t j = 0 ; j < i; ++j) {
        buf[i - j] = length & 0xFF;
        length = length >> 8;
    }
    
    return i + 1;
}

#pragma mark - 根据base64码获取公钥
- (NSData*)publicKeyBitsWithString:(NSString*)str {
    static const unsigned char _encodedRSAEncryptionOID[15] = {
        
        /* Sequence of length 0xd made up of OID followed by NULL */
        0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
        0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00
        
    };
    
    NSData *publicKeyBits_ = [str base64DecodedData];
    
    // OK - that gives us the "BITSTRING component of a full DER
    // encoded RSA public key - we now need to build the rest
    
    unsigned char builder[15];
    NSMutableData * encKey = [NSMutableData dataWithCapacity:0];
    NSUInteger bitstringEncLength;
    
    // When we get to the bitstring - how will we encode it?
    if ([publicKeyBits_ length] + 1 < 128)
        bitstringEncLength = 1;
    else
        bitstringEncLength = (([publicKeyBits_ length] +1) / 256) + 2;
    
    // Overall we have a sequence of a certain length
    builder[0] = 0x30;    // ASN.1 encoding representing a SEQUENCE
    // Build up overall size made up of -
    // size of OID + size of bitstring encoding + size of actual key
    size_t i = sizeof(_encodedRSAEncryptionOID) + 2 + bitstringEncLength +
    [publicKeyBits_ length];
    size_t j = encodeLength(&builder[1], i);
    [encKey appendBytes:builder length:j +1];
    
    // First part of the sequence is the OID
    [encKey appendBytes:_encodedRSAEncryptionOID
                 length:sizeof(_encodedRSAEncryptionOID)];
    
    // Now add the bitstring
    builder[0] = 0x03;
    j = encodeLength(&builder[1], [publicKeyBits_ length] + 1);
    builder[j+1] = 0x00;
    [encKey appendBytes:builder length:j + 2];
    
    // Now the actual key
    [encKey appendData:publicKeyBits_];
    
    return encKey;
}

#pragma mark - 将公钥编程字符串

- (NSString*)publicKeyBase64 {
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:OpenSSLRSAPublicKeyFile]) {
        NSString *str = [NSString stringWithContentsOfFile:OpenSSLRSAPublicKeyFile encoding:NSUTF8StringEncoding error:nil];
        
        /*
         This return value based on the key that generated by openssl.
         
         -----BEGIN RSA PUBLIC KEY-----
         MIGHAoGBAOp5TLclpWCaNDzHYPfB26SLmS8vlSXH4PyKopz5OS5Vx994FBQQLwv9
         2pIJQsBk09egrL0gbASK1VCwDt0MmaiyrNFl/xaEzB/VOvjoojBUzMMIca9fKmx5
         GAzSbSP7we64dhvrziuuNVTuM/e2XSa2skKFHMI0bCq4+pNYhvRhAgED
         -----END RSA PUBLIC KEY-----
         */
        NSData *data = [self publicKeyBitsWithString:[[str componentsSeparatedByString:@"-----"] objectAtIndex:2]];
        
        return [data base64EncodedString];
    }
    return nil;
}

- (NSString*)privateKeyBase64 {
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:OpenSSLRSAPrivateKeyFile]) {
        NSString *str = [NSString stringWithContentsOfFile:OpenSSLRSAPrivateKeyFile encoding:NSUTF8StringEncoding error:nil];
        DLog(@"%@", OpenSSLRSAPrivateKeyFile);
        
        /*
         This return value based on the key that generated by openssl.
         
         -----BEGIN RSA PRIVATE KEY-----
         MIICXAIBAAKBgQDqeUy3JaVgmjQ8x2D3wduki5kvL5Ulx+D8iqKc+TkuVcffeBQU
         EC8L/dqSCULAZNPXoKy9IGwEitVQsA7dDJmosqzRZf8WhMwf1Tr46KIwVMzDCHGv
         XypseRgM0m0j+8HuuHYb684rrjVU7jP3tl0mtrJChRzCNGwquPqTWIb0YQIBAwKB
         gQCcUN3Pbm5AZs192kClK+fDB7t0ymNuhUCoXGxopiYe49qU+rgNYB9dU+cMBiyA
         QzflFch+FZ1YXI41yrSTXbvEhcYQy7jdFVJiqNH4Cu767ETzLMFDiDXIv5/h72iN
         hfeRWTW/KbyZbEtq/HeTjIg7rP3h8Fveh/Fj3EY4bmlqgwJBAPbQFmacHXeO4xcP
         aLhFVX/lDrmL7o1TIFNAp8xH/Kqf+L4+uSzoqyvPzO3w2ATdge+VnLhrxzzU48eg
         Y3wHpY8CQQDzM6HNza1tQajA8Jwf9mJygEeLw9uFhp8GZ5IfCFMILpv0ZsQASppf
         9GeFj8Jes0tDn9LkJy0rrTEm8Ns24S8PAkEApIq5mb1o+l9CD1+bJYOOVUNfJl1J
         s4zAN4Bv3YVTHGql1CnQyJscx9/d8/XlWJOr9Q5oevKE0ziX2mrs/VpuXwJBAKIi
         a96JHkjWcICgaBVO7ExVhQfX565Zv1maYWoFjLAfEqLvLVWHEZVNmlkKgZR3h4Jq
         jJgaHh0eIMSgkiSWH18CQGsFhFEdBonmeIm1kY1YWjpM4WS0kUlXOC3sCYg8eXFe
         YEEr9pnY+hhDFegEItQd1hAvrqQhpxhX7HhNNxUoPp4=
         -----END RSA PRIVATE KEY-----
         */
        return [[str componentsSeparatedByString:@"-----"] objectAtIndex:2];
    }
    return nil;
}

- (id)init {
    if (self = [super init]) {
        //load RSA if it is exsit
//        NSFileManager *fm = [NSFileManager defaultManager];
//        if (![fm fileExistsAtPath:OpenSSLRSAKeyDir]) {
//            [fm createDirectoryAtPath:OpenSSLRSAKeyDir withIntermediateDirectories:YES attributes:nil error:nil];
//            DLog(@"%@",OpenSSLRSAKeyDir);
//        }
    }
    return self;
}

+ (id)shareInstance {
    static OpenSSLRSAWrapper *_opensslWrapper = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _opensslWrapper = [[self alloc] init];
    });
    return _opensslWrapper;
}

#pragma mark - 判断公钥私钥本地是否存在

+ (BOOL)canImportRSAKeys {
    NSFileManager *fm = [NSFileManager defaultManager];
    return [fm fileExistsAtPath:OpenSSLRSAPublicKeyFile] && [fm fileExistsAtPath:OpenSSLRSAPrivateKeyFile];
}

// 生成两个公钥私钥对

- (BOOL)generateRSAKeyPairWithKeySize:(NSInteger)keySize  {
    if (NULL != _rsa) {
        RSA_free(_rsa);
        _rsa = NULL;
    }
    _rsa = RSA_generate_key((int)keySize,RSA_F4,NULL,NULL);
    assert(_rsa != NULL);
    
    if (_rsa) {
        return YES;
    }return NO;
}


#pragma mark - 导出RSA公钥私钥
- (BOOL)exportRSAKeys {
    assert(_rsa != NULL);
    
    if (_rsa != NULL) {
        FILE *filepub,*filepri;
        filepri = fopen([OpenSSLRSAPrivateKeyFile cStringUsingEncoding:NSASCIIStringEncoding],"w");
        filepub = fopen([OpenSSLRSAPublicKeyFile cStringUsingEncoding:NSASCIIStringEncoding],"w");
        
        if (NULL != filepub && NULL != filepri) {
            int retpri = -1;
            int retpub = -1;
            
            RSA *_pribrsa = RSAPrivateKey_dup(_rsa);
            assert(_pribrsa != NULL);
            char passwd[]="aspen";
//            retpri = PEM_write_RSAPrivateKey(filepri, _pribrsa, NULL, NULL, 512, NULL, NULL);
            retpri = PEM_write_RSAPrivateKey(filepri, _pribrsa, EVP_des_ede3(), (unsigned char*)passwd, sizeof(passwd), NULL, NULL);
//            PEM_write_RSAPrivateKey(FILE *fp, RSA *x, const EVP_CIPHER *enc, unsigned char *kstr, int klen, pem_password_cb *cb, void *u)
//           PEM_read_bio_PrivateKey(<#BIO *bp#>, <#EVP_PKEY **x#>, <#pem_password_cb *cb#>, <#void *u#>)
//            pem_password_cb *cb = 
//            pem_password_cb(char *buf, int size, int rwflag, void *userdata);
            RSA_free(_pribrsa);
            
            RSA *_pubrsa = RSAPublicKey_dup(_rsa);
            assert(_pubrsa != NULL);
            retpub = PEM_write_RSAPublicKey(filepub, _pubrsa);
            RSA_free(_pubrsa);
            
            fclose(filepub);
            fclose(filepri);
            
            return (retpri + retpub > 1) ? YES : NO;
        }
    }
    return NO;
}

#pragma mark - 根据钥匙类型导入公钥私钥

- (BOOL)importRSAKeyWithType:(KeyType)type {
    FILE *file;
    
    if (type == KeyTypePublic) {
        file = fopen([OpenSSLRSAPublicKeyFile cStringUsingEncoding:NSASCIIStringEncoding],"rb");
    }else{
        file = fopen([OpenSSLRSAPrivateKeyFile1 cStringUsingEncoding:NSASCIIStringEncoding],"rb");
    }
    
    if (NULL != file) {
        
        if (type == KeyTypePublic) {
            _rsa = PEM_read_RSAPublicKey(file,NULL, NULL, NULL);
            assert(_rsa != NULL);
            // PEM_write_RSAPublicKey(stdout, _rsa);
        }else{
            _rsa = PEM_read_RSAPrivateKey(file, NULL, NULL, NULL);
            assert(_rsa != NULL);
            PEM_write_RSAPrivateKey(stdout, _rsa, NULL, NULL, 0, NULL, NULL);
        }
        
        fclose(file);
        return (_rsa != NULL)?YES:NO;
    } return NO;
}

#pragma mark - 加密信息

- (NSData*)encryptRSAKeyWithType:(KeyType)keyType paddingType:(RSA_PADDING_TYPE)padding data:(NSData*)d {
    if (d && [d length]) {
        NSUInteger flen = [d length];
        unsigned char from[flen];
        bzero(from, sizeof(from));
        memcpy(from, [d bytes], [d length]);
        
        unsigned char to[128];
        bzero(to, sizeof(to));
        
        [self encryptRSAKeyWithType:keyType :from :flen :to :padding];
        
        return [NSData dataWithBytes:to length:sizeof(to)];
    }
    return nil;
}

#pragma mark - 根据编码格式加密

- (NSData*)encryptRSAKeyWithType:(KeyType)keyType paddingType:(RSA_PADDING_TYPE)padding plainText:(NSString*)text usingEncoding:(NSStringEncoding)encode {
    if (text && [text length]) {
        return [self encryptRSAKeyWithType:keyType paddingType:padding data:[text dataUsingEncoding:encode]];
    }return nil;
}

#pragma mark - 根据根据钥匙类型 加密形式  需要解密的data 解密的编码格式解密

- (NSString*)decryptRSAKeyWithType:(KeyType)keyType paddingType:(RSA_PADDING_TYPE)padding plainTextData:(NSData*)data usingEncoding:(NSStringEncoding)encode {
    if (data && [data length]) 
    {
        NSData *decryptData = [self decryptRSAKeyWithType:keyType paddingType:padding encryptedData:data];
        return [[NSString alloc] initWithData:decryptData encoding:encode];
    }return nil;
}

#pragma mark - 基础加密算法

- (int)encryptRSAKeyWithType:(KeyType)keyType :(const unsigned char *)from :(NSUInteger)flen :(unsigned char *)to :(RSA_PADDING_TYPE)padding{
    if (from != NULL && to != NULL) {
        int status = RSA_check_key(_rsa);
        if (!status) {
            DLog(@"status code %i",status);
            return -1;
        }
        switch (keyType) {
            case KeyTypePrivate:{
                //start encrypt
                status =  RSA_private_encrypt((int)flen, from,to, _rsa,  padding);
            }
                break;
                
            default:{
                //start encrypt
                status =  RSA_public_encrypt((int)flen,from,to, _rsa,  padding);
            }
                break;
        }
        
        return status;
    }return -1;
}

#pragma mark - 根据钥匙类型和钥匙名称导入公钥私钥

- (BOOL)importRSAKeyWithType:(KeyType)type keyName:(NSString *)name {
    FILE *file;
    NSString *path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:name];
    NSLog(@"导入key的path -- %@",path);
    if (type == KeyTypePublic) {
        file = fopen([OpenSSLRSAPublicKeyFile cStringUsingEncoding:NSASCIIStringEncoding],"rb");
    } else {
        file = fopen([path cStringUsingEncoding:NSASCIIStringEncoding],"rb");
    }
    
    if (NULL != file) {
        if (type == KeyTypePublic) {
            _rsa = PEM_read_RSAPublicKey(file,NULL, NULL, NULL);
            assert(_rsa != NULL);
            // PEM_write_RSAPublicKey(stdout, _rsa);
        }else{
            _rsa = PEM_read_RSAPrivateKey(file, NULL, NULL, NULL);
            assert(_rsa != NULL);
            PEM_write_RSAPrivateKey(stdout, _rsa, NULL, NULL, 0, NULL, NULL);
        }
        fclose(file);
        return (_rsa != NULL) ? YES : NO;
    }
    return NO;
}


#pragma mark - 根据钥匙类型 加密形式  需要解密的data解密

- (NSData*)decryptRSAKeyWithType:(KeyType)keyType paddingType:(RSA_PADDING_TYPE)padding encryptedData:(NSData*)data {
    if (data && [data length]) {
        NSUInteger flen = [data length];
        unsigned char from[flen];
        bzero(from, sizeof(from));
        memcpy(from, [data bytes], [data length]);
        
// 这里可以更改解密密文长度
        unsigned char to[32];
        bzero(to, sizeof(to));
        
        [self decryptRSAKeyWithType:keyType :from :flen :to :padding];
        
        return [NSData dataWithBytes:to length:sizeof(to)];
    }
    return nil;
}

- (NSData *)decryptRSAKeyWithType:(KeyType)keyType paddingType:(RSA_PADDING_TYPE)padding encryptedData:(NSData *)data andKeyName:(NSString *)name {
    [self importRSAKeyWithType:KeyTypePrivate keyName:name];
    if (data && [data length])
    {
        NSUInteger flen = [data length];
        unsigned char from[flen];
        bzero(from, sizeof(from));
        memcpy(from, [data bytes], [data length]);
        
        unsigned char to[32];
        bzero(to, sizeof(to));
        
        [self decryptRSAKeyWithType:keyType :from :flen :to :padding];
        return [NSData dataWithBytes:to length:sizeof(to)];
    }
    return nil;
}


#pragma mark - 基础解密算法
- (int)decryptRSAKeyWithType:(KeyType)keyType :(const unsigned char *)from :(NSUInteger)flen :(unsigned char *)to :(RSA_PADDING_TYPE)padding {
    if (from != NULL && to != NULL) {
        int status = RSA_check_key(_rsa);
        if (!status) {
            DLog(@"status code %i",status);
            return -1;
        }
        switch (keyType) {
            case KeyTypePrivate:{
                //start encrypt
                status =  RSA_private_decrypt((int)flen, from, to, _rsa,  padding);
//                RSA_private_decrypt(<#int flen#>, <#const unsigned char *from#>, <#unsigned char *to#>, <#RSA *rsa#>, <#int padding#>)
            }
                break;
                
            default:{
                //start encrypt
                status =  RSA_public_decrypt((int)flen,from,to, _rsa,  padding);
            }
                break;
        }
        return status;
    }
    return -1;
}

- (int)getBlockSizeWithRSA_PADDING_TYPE:(RSA_PADDING_TYPE)padding_type {
    int len = RSA_size(_rsa);
    
    if (padding_type == RSA_PADDING_TYPE_PKCS1 || padding_type == RSA_PADDING_TYPE_SSLV23) {
        len -= 11;
    }
    return len;
}

- (NSString*)decrypt:(NSString*)encryText modulus:(NSString*)mod exponent:(NSString*)exp {
    NSString * hexString = encryText; 
    NSUInteger hexStringLength= [hexString length] / 2;
    
    //unsigned char enc_bin[144]; 
    unsigned char dec_bin[hexStringLength]; 
    //int enc_len; 
    int dec_len; 
    RSA * rsa_pub = RSA_new();

    const char *N=[mod UTF8String]; 
    const char *E=[exp UTF8String]; 

    char * myBuffer = (char *)malloc((int)[hexString length] / 2 + 1); 
    bzero(myBuffer, [hexString length] / 2 + 1); 
    for (int i = 0; i < [hexString length] - 1; i += 2) { 
        unsigned int anInt; 
        NSString * hexCharStr = [hexString substringWithRange:NSMakeRange(i, 2)]; 
        NSScanner * scanner = [[NSScanner alloc] initWithString:hexCharStr]; 
        [scanner scanHexInt:&anInt]; 
        myBuffer[i / 2] = (char)anInt; 
    } 
    
    printf("Mybuffer: %s",myBuffer);
    
    if (!BN_dec2bn(&rsa_pub->n, N)) { 
        printf("NO CARGO EL MODULO"); 
    } 
    printf(" N: %s\n", N); 
    printf(" n: %s\n", BN_bn2dec(rsa_pub->n)); 
    
    
    if (!BN_dec2bn(&rsa_pub->e, E)) { 
        printf("NO CARGO EL EXPONENTE"); 
    } 
    printf(" E: %s\n", E); 
    printf(" e: %s\n", BN_bn2dec(rsa_pub->e)); 
    
    printf("public key size : %d bits\n", RSA_size(rsa_pub)); 
    NSMutableString *entring = [NSMutableString stringWithCapacity:128]; 
    for (int i = 0; i < hexStringLength; i++) { 
        [entring appendFormat:@"%x", myBuffer[i]]; 
    } 
    /* decrypt */ 
    if ((dec_len = RSA_public_decrypt((int)hexStringLength,
                                      (unsigned char*)myBuffer, dec_bin, rsa_pub,RSA_NO_PADDING))<0) {
        printf("NO\n ");
    } 
    printf("decrypted data:\n %s", dec_bin); 
    // print_hex(dec_bin, dec_len); 
    
    NSMutableString *decryptString = [[NSMutableString alloc] initWithBytes:dec_bin 
                                                                     length:strlen((char *)dec_bin) 
                                                                   encoding:NSUTF8StringEncoding]; 
    return decryptString; 
}

- (NSString*)decrypt:(NSString*)encryText modulus:(NSString*)mod exponent:(NSString*)exp P:(NSString *)pe Q:(NSString *)qe DP:(NSString *)dp DQ:(NSString *)dq InverseQ:(NSString *)inverseQ  D:(NSString *)de {
    
    NSString * hexString = encryText; 
    NSUInteger hexStringLength= [hexString length] / 2;
    
    //unsigned char enc_bin[144]; 
    unsigned char dec_bin[hexStringLength]; 
    //int enc_len; 
    int dec_len; 
    RSA * rsa_pub = RSA_new(); 
    
    const char *N=[mod UTF8String]; 
    const char *E=[exp UTF8String]; 
    const char *D=[de UTF8String];
    const char *P=[pe UTF8String];
    const char *Q=[qe UTF8String];
    const char *DMP=[dp UTF8String];
    const char *DMQ=[dq UTF8String];
    const char *IQMP=[inverseQ UTF8String];
    
    char * myBuffer = (char *)malloc((int)[hexString length] / 2 + 1); 
    bzero(myBuffer, [hexString length] / 2 + 1); 
    for (int i = 0; i < [hexString length] - 1; i += 2) { 
        unsigned int anInt; 
        NSString * hexCharStr = [hexString substringWithRange:NSMakeRange(i, 2)]; 
        NSScanner * scanner = [[NSScanner alloc] initWithString:hexCharStr]; 
        [scanner scanHexInt:&anInt]; 
        myBuffer[i / 2] = (char)anInt; 
    } 
    
    printf("Mybuffer: %s",myBuffer); 
    
    /*
     BIGNUM *n;
     BIGNUM *e;
     BIGNUM *d;
     BIGNUM *p;
     BIGNUM *q;
     BIGNUM *dmp1;
     BIGNUM *dmq1;
     BIGNUM *iqmp;
     */
    
    if (!BN_dec2bn(&rsa_pub->n, N)) { 
        printf("NO CARGO EL MODULO"); 
    } 
    printf(" N: %s\n", N); 
    printf(" n: %s\n", BN_bn2dec(rsa_pub->n)); 
    
    
    if (!BN_dec2bn(&rsa_pub->e, E)) { 
        printf("NO CARGO EL EXPONENTE"); 
    } 
    printf(" E: %s\n", E); 
    printf(" e: %s\n", BN_bn2dec(rsa_pub->e));
    
    if (!BN_dec2bn(&rsa_pub->d, D)) { 
        printf("NO CARGO EL EXPONENTE"); 
    } 
    printf(" D: %s\n", D); 
    printf(" d: %s\n", BN_bn2dec(rsa_pub->d)); 
    
    if (!BN_dec2bn(&rsa_pub->p, P)) { 
        printf("NO CARGO EL EXPONENTE"); 
    } 
    printf(" P: %s\n", P); 
    printf(" p: %s\n", BN_bn2dec(rsa_pub->p)); 

    if (!BN_dec2bn(&rsa_pub->q, Q)) { 
        printf("NO CARGO EL EXPONENTE"); 
    } 
    printf(" Q: %s\n", Q); 
    printf(" q: %s\n", BN_bn2dec(rsa_pub->q)); 
    
    if (!BN_dec2bn(&rsa_pub->dmp1, DMP)) { 
        printf("NO CARGO EL EXPONENTE"); 
    } 
    printf(" DMP: %s\n", DMP); 
    printf(" dmp: %s\n", BN_bn2dec(rsa_pub->dmp1)); 

    if (!BN_dec2bn(&rsa_pub->dmq1, DMQ)) { 
        printf("NO CARGO EL EXPONENTE"); 
    } 
    printf(" DMQ: %s\n", DMQ); 
    printf(" dmq: %s\n", BN_bn2dec(rsa_pub->dmq1)); 

    if (!BN_dec2bn(&rsa_pub->iqmp, IQMP)) { 
        printf("NO CARGO EL EXPONENTE"); 
    } 
    printf(" IQMP: %s\n", IQMP); 
    printf(" e: %s\n", BN_bn2dec(rsa_pub->iqmp)); 

    printf("public key size : %d bits\n", RSA_size(rsa_pub)); 
    
    NSMutableString *entring = [NSMutableString stringWithCapacity:128]; 
    for (int i = 0; i < hexStringLength; i++) { 
        [entring appendFormat:@"%x", myBuffer[i]]; 
    } 
    /* decrypt */ 
    if ((dec_len = RSA_public_decrypt((int)hexStringLength, (unsigned char*)myBuffer, dec_bin, rsa_pub,RSA_PKCS1_PADDING))<0) {
        printf("NO\n "); 
    } 
    printf("decrypted data:\n %s", dec_bin); 
    // print_hex(dec_bin, dec_len); 
    
    NSMutableString *decryptString = [[NSMutableString alloc] initWithBytes:dec_bin 
                                                                     length:strlen((char *)dec_bin) 
                                                                   encoding:NSUTF8StringEncoding]; 
    return decryptString; 
}

- (NSString*)decryptData:(NSData *)data modulus:(NSString*)mod exponent:(NSString*)exp P:(NSString *)pe Q:(NSString *)qe DP:(NSString *)dp DQ:(NSString *)dq InverseQ:(NSString *)inverseQ  D:(NSString *)de { 
    //int enc_len; 
    int dec_len; 
    RSA * rsa_private = RSA_new(); 
    
    const char *N=[mod UTF8String]; 
    const char *E=[exp UTF8String]; 
    const char *D=[de UTF8String];
    const char *P=[pe UTF8String];
    const char *Q=[qe UTF8String];
    const char *DMP=[dp UTF8String];
    const char *DMQ=[dq UTF8String];
    const char *IQMP=[inverseQ UTF8String];
    
    
    /*
     BIGNUM *n;
     BIGNUM *e;
     BIGNUM *d;
     BIGNUM *p;
     BIGNUM *q;
     BIGNUM *dmp1;
     BIGNUM *dmq1;
     BIGNUM *iqmp;
     */
    
    if (!BN_dec2bn(&rsa_private->n, N)) { 
        printf("NO CARGO EL MODULO"); 
    } 
    printf(" N: %s\n", N); 
    printf(" n: %s\n", BN_bn2dec(rsa_private->n)); 
    
    
    if (!BN_dec2bn(&rsa_private->e, E)) { 
        printf("NO CARGO EL EXPONENTE"); 
    } 
    printf(" E: %s\n", E); 
    printf(" e: %s\n", BN_bn2dec(rsa_private->e));
    
    if (!BN_dec2bn(&rsa_private->d, D)) { 
        printf("NO CARGO EL EXPONENTE"); 
    } 
    printf(" D: %s\n", D); 
    printf(" d: %s\n", BN_bn2dec(rsa_private->d)); 
    
    if (!BN_dec2bn(&rsa_private->p, P)) { 
        printf("NO CARGO EL EXPONENTE"); 
    } 
    printf(" P: %s\n", P); 
    printf(" p: %s\n", BN_bn2dec(rsa_private->p)); 
    
    if (!BN_dec2bn(&rsa_private->q, Q)) { 
        printf("NO CARGO EL EXPONENTE"); 
    } 
    printf(" Q: %s\n", Q); 
    printf(" q: %s\n", BN_bn2dec(rsa_private->q)); 
    
    if (!BN_dec2bn(&rsa_private->dmp1, DMP)) { 
        printf("NO CARGO EL EXPONENTE"); 
    } 
    printf(" DMP: %s\n", DMP); 
    printf(" dmp: %s\n", BN_bn2dec(rsa_private->dmp1)); 
    
    if (!BN_dec2bn(&rsa_private->dmq1, DMQ)) { 
        printf("NO CARGO EL EXPONENTE"); 
    } 
    printf(" DMQ: %s\n", DMQ); 
    printf(" dmq: %s\n", BN_bn2dec(rsa_private->dmq1)); 
    
    if (!BN_dec2bn(&rsa_private->iqmp, IQMP)) { 
        printf("NO CARGO EL EXPONENTE"); 
    } 
    printf(" IQMP: %s\n", IQMP); 
    printf(" e: %s\n", BN_bn2dec(rsa_private->iqmp)); 
    
    printf("public key size : %d bits\n", RSA_size(rsa_private));
    
    BN_CTX *ctx=NULL;
    
    if ((rsa_private->_method_mod_n == NULL) && (rsa_private->flags & RSA_FLAG_CACHE_PRIVATE)) {
		BN_MONT_CTX* bn_mont_ctx;
		if ((bn_mont_ctx=BN_MONT_CTX_new()) == NULL) {
            DLog(@"error");
        }
		if (!BN_MONT_CTX_set(bn_mont_ctx,rsa_private->n,ctx)) {
            BN_MONT_CTX_free(bn_mont_ctx);
            DLog(@"error");
        }
		if (rsa_private->_method_mod_n == NULL) {
            /* other thread may have finished first */
			CRYPTO_w_lock(CRYPTO_LOCK_RSA);
			if (rsa_private->_method_mod_n == NULL) {
				rsa_private->_method_mod_n = bn_mont_ctx;
				bn_mont_ctx = NULL;
            }
			CRYPTO_w_unlock(CRYPTO_LOCK_RSA);
        }
		if (bn_mont_ctx)
			BN_MONT_CTX_free(bn_mont_ctx);
    }
    if (rsa_private->_method_mod_p == NULL) {
        BN_MONT_CTX* bn_mont_ctx;
        if ((bn_mont_ctx=BN_MONT_CTX_new()) == NULL) {
            DLog(@"error");
        }
        if (!BN_MONT_CTX_set(bn_mont_ctx,rsa_private->p,ctx)) {
            BN_MONT_CTX_free(bn_mont_ctx);
            DLog(@"error");
        }
        if (rsa_private->_method_mod_p == NULL) {
            /* other thread may have finished first */
            CRYPTO_w_lock(CRYPTO_LOCK_RSA);
            if (rsa_private->_method_mod_p == NULL) {
                rsa_private->_method_mod_p = bn_mont_ctx;
                bn_mont_ctx = NULL;
            }
            CRYPTO_w_unlock(CRYPTO_LOCK_RSA);
        }
        if (bn_mont_ctx)
            BN_MONT_CTX_free(bn_mont_ctx);
    }
    
    if (rsa_private->_method_mod_q == NULL) {
        BN_MONT_CTX* bn_mont_ctx;
        if ((bn_mont_ctx=BN_MONT_CTX_new()) == NULL) {
            DLog(@"error");
        }
        if (!BN_MONT_CTX_set(bn_mont_ctx,rsa_private->q,ctx)) {
            BN_MONT_CTX_free(bn_mont_ctx);
            DLog(@"error");
        }
        if (rsa_private->_method_mod_q == NULL) {
            /* other thread may have finished first */
            CRYPTO_w_lock(CRYPTO_LOCK_RSA);
            if (rsa_private->_method_mod_q == NULL) {
                rsa_private->_method_mod_q = bn_mont_ctx;
                bn_mont_ctx = NULL;
            }
            CRYPTO_w_unlock(CRYPTO_LOCK_RSA);
        }
        if (bn_mont_ctx)
            BN_MONT_CTX_free(bn_mont_ctx);
    }
    
    /* decrypt */ 
    
    NSString *decStr = nil;
    if (data && [data length]) {
        NSUInteger flen = [data length];
        unsigned char from[flen];
        bzero(from, sizeof(from));
        memcpy(from, [data bytes], [data length]);
        
        unsigned char to[128];
        bzero(to, sizeof(to));
        // RSA_public_decrypt(hexStringLength, (unsigned char*)myBuffer, dec_bin, rsa_pub,RSA_PKCS1_PADDING)
        if ((dec_len = RSA_private_decrypt((int)flen, from,to,rsa_private,RSA_NO_PADDING))<0) {
            printf("NO\n "); 
        } 
        NSData *decData = [NSData dataWithBytes:to length:sizeof(to)];
        decStr = [[NSString alloc] initWithData:decData encoding:NSUTF8StringEncoding];
    }
    return decStr;
}

@end