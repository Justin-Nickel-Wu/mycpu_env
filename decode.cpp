#include <bits/stdc++.h>
using namespace std;
char inst[10];
char read_ch(){
    char ch=getchar();
    while (!isalpha(ch) && !isdigit(ch))
        ch=getchar();
    return ch>='a'&&ch<='z'?ch-'a'+'A':ch;
}
void print(char ch){
    int res[4],w=isdigit(ch)?ch-'0':ch-'A'+10;
    for (int i=0;i<4;i++)
        if (w&(1<<i))
            res[i]=1;
        else  
            res[i]=0;
    for (int i=3;i>=0;i--)
        printf("%d",res[i]);
}
int main(){
    while (1){
        printf("输入8位16进制指令\n");
        for (int i=1;i<=8;i++){
            inst[i]=read_ch();
            if (inst[i]=='Q')
                return 0;
        }
        printf("二进制指令码为\n");
        for (int i=1;i<=8;i++)
            print(inst[i]),putchar(' ');
        putchar('\n');
    }
    return 0;
}