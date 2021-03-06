//
//  ChatViewController.m
//  SCUTChat
//
//  Created by bwu on 16/5/14.
//  Copyright © 2016年 wubiao. All rights reserved.
//

#import "ChatViewController.h"
#import "SCUTChatCell.h"
#import "EMCDDeviceManager.h"
#import "SCUTAudioPlayTool.h"
#import "SCUTTimeCell.h"
#import "SCUTTimeTool.h"



@interface ChatViewController () <UITableViewDataSource,UITableViewDelegate,UITextViewDelegate,EMChatManagerDelegate,UIImagePickerControllerDelegate>
/**输入工具条底部的约束*/
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *inputToolBarBottomConstraint;
@property (weak, nonatomic) IBOutlet UITextView *textView;

/** 数据源 */
@property (nonatomic, strong) NSMutableArray *dataSources;

@property (weak, nonatomic) IBOutlet UIButton *recordBtn;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

/** 计算高度的cell工具对象 */
@property (nonatomic, strong) SCUTChatCell *chatCellTool;

/** InputToolBar 高度的约束*/
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *inputToolBarHegihtConstraint;


/** 当前添加的时间 */
@property (nonatomic, copy) NSString *currentTimeStr;


/** 当前会话对象 */
@property (nonatomic, strong) EMConversation *conversation;

@end

@implementation ChatViewController

-(NSMutableArray *)dataSources{
    if (!_dataSources) {
        _dataSources = [NSMutableArray array];
    }
    
    return _dataSources;
}

- (void)viewDidLoad {
    [super viewDidLoad];
 
 
    self.title = self.buddy.username;
    self.tableView.backgroundColor = [UIColor colorWithRed:246/255.0 green:246/255.0 blue:246/255.0 alpha:1];
    
    // 加载本地数据库聊天记录（MessageV1）
    [self loadLocalChatRecords];
    
    
    // 设置聊天管理器的代理
    [[EaseMob sharedInstance].chatManager addDelegate:self delegateQueue:nil];
    
    // 给计算高度的cell工具对象 赋值
    self.chatCellTool = [self.tableView dequeueReusableCellWithIdentifier:ReceiverCell];
    
    //1.监听键盘弹出，把inputToolbar(输入工具条)往上移
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(kbWillShow:) name:UIKeyboardWillShowNotification object:nil];
    
    //2.监听键盘退出，inputToolbar恢复原位
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(kbWillHide:) name:UIKeyboardWillHideNotification object:nil];
    
}


-(void)loadLocalChatRecords{
    
    //假设在数组的第一位置添加时间
//        [self.dataSources addObject:@"16:06"];
    
    // 要获取本地聊天记录使用 会话对象
    EMConversation *conversation = [[EaseMob sharedInstance].chatManager conversationForChatter:self.buddy.username conversationType:eConversationTypeChat];
    
    self.conversation = conversation;
    
    // 加载与当前聊天用户所有聊天记录
    NSArray *messages = [conversation loadAllMessages];
    
    for (id obj in messages) {
        NSLog(@"%@",[obj class]);
    }
    
//    // 添加到数据源,数据源中保存的都是 模型对象
//    [self.dataSources addObjectsFromArray:messages];
 
    for (EMMessage *msgObj in messages) {
        [self addDataSourcesWithMessage:msgObj];
    }
}


#pragma mark 键盘显示时会触发的方法
-(void)kbWillShow:(NSNotification *)noti{
    
    //1.获取键盘高度
    //1.1获取键盘结束时候的位置
    CGRect kbEndFrm = [noti.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat kbHeight = kbEndFrm.size.height;
    
    
    //2.更改inputToolbar 底部约束
    self.inputToolBarBottomConstraint.constant = kbHeight;
    //添加动画
    [UIView animateWithDuration:0.25 animations:^{
        [self.view layoutIfNeeded];
    }];
    
    
}
#pragma mark 键盘退出时会触发的方法
-(void)kbWillHide:(NSNotification *)noti{
    //inputToolbar恢复原位
    self.inputToolBarBottomConstraint.constant = 0;
}


-(void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}



#pragma mark 表格数据源
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.dataSources.count;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    if ([self.dataSources[indexPath.row] isKindOfClass:[NSString class]]) {  //时间Cell的高度固定
        return 18;
    }
    // 设置label的数据
    // 1.获取消息模型
    EMMessage *msg = self.dataSources[indexPath.row];
    
    self.chatCellTool.message = msg;
    //    self.chatCellTool.messageLabel.text = self.dataSources[indexPath.row];
    return [self.chatCellTool cellHeghit];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    //0.注意只有时间的Cell数据源是NSSting,其他类型的Cell都对应着模型
    //判断数据源类型
    if ([self.dataSources[indexPath.row] isKindOfClass:[NSString class]]) {//显示时间cell
        SCUTTimeCell *timeCell = [tableView dequeueReusableCellWithIdentifier:@"TimeCell"];
        timeCell.timeLabel.text = self.dataSources[indexPath.row];
        return timeCell;
    }
    
    
    //1.先获取消息模型
    EMMessage *message = self.dataSources[indexPath.row];
    //    EMMessage
    /* from:xmgtest1 to:xmgtest7 发送方（自己）
     * from:xmgtest7 to:xmgtest1 接收方 （好友）
     */
    
    SCUTChatCell *cell = nil;
    if ([message.from isEqualToString:self.buddy.username]) {//接收方
        cell = [tableView dequeueReusableCellWithIdentifier:ReceiverCell];
    }else{//发送方
        cell = [tableView dequeueReusableCellWithIdentifier:SenderCell];
    }
    //显示内容
    cell.message = message;
    
    return cell;
    
    
}



#pragma mark - UITextView代理,文字改变时候调用
-(void)textViewDidChange:(UITextView *)textView{
    
   // NSLog(@"contentOffset %@",NSStringFromCGPoint(textView.contentOffset));
    // 1.计算TextView的高度，
    CGFloat textViewH = 0;
    CGFloat minHeight = 33;//textView最小的高度
    CGFloat maxHeight = 68;//textView最大的高度
    
    // 获取contentSize的高度
    CGFloat contentHeight = textView.contentSize.height;
    if (contentHeight < minHeight) {
        textViewH = minHeight;
    }else if (contentHeight > maxHeight){
        textViewH = maxHeight;
    }else{
        textViewH = contentHeight;
    }
    // 2.监听Send事件--判断最后的一个字符是不是换行字符
    if ([textView.text hasSuffix:@"\n"]) {
        NSLog(@"发送操作");
        [self sendText:textView.text];
        
        // 清空textView的文字
        textView.text = nil;
        
        // 发送时，textViewH的高度为33
        textViewH = minHeight;
        
    }
    
    // 3.调整整个InputToolBar 高度
    self.inputToolBarHegihtConstraint.constant = 8 + 11 + textViewH;
    // 加个动画
    [UIView animateWithDuration:0.25 animations:^{
        [self.view layoutIfNeeded];
    }];
    
    
    // 4.记光标回到原位-技巧
    [textView setContentOffset:CGPointZero animated:YES];
    [textView scrollRangeToVisible:textView.selectedRange];
}


#pragma mark - 发送聊天文本
-(void)sendText:(NSString *)text{
    
    // 把最后一个换行字符去除
#warning 换行字符 只占用一个长度
    text = [text substringToIndex:text.length - 1];
#warning 每一种消息类型对象不同的消息体
    //    EMTextMessageBody 文本消息体
    //    EMVoiceMessageBody 录音消息体
    //    EMVideoMessageBody 视频消息体
    //    EMLocationMessageBody 位置消息体
    //    EMImageMessageBody 图片消息体
    NSLog(@"要发送给 %@",self.buddy.username);
    // 创建一个聊天文本对象
    EMChatText *chatText = [[EMChatText alloc] initWithText:text];
    //创建一个文本消息体
    EMTextMessageBody *textBody = [[EMTextMessageBody alloc] initWithChatObject:chatText];
    
    [self sendMessage:textBody];
}

-(void)scrollToBottom{
    //1.获取最后一行
    if (self.dataSources.count == 0) {
        return;
    }

    NSIndexPath *lastIndex = [NSIndexPath indexPathForRow:self.dataSources.count - 1 inSection:0];
    [self.tableView scrollToRowAtIndexPath:lastIndex atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}

 -(void)didReceiveMessage:(EMMessage *)message
{
#warning from 一定等于当前聊天用户才可以刷新数据
    //test1 - test7
    //test1 - test8
    if ([message.from isEqualToString:self.buddy.username]) {
        //1.把接收的消息添加到数据源
        [self addDataSourcesWithMessage:message];
        
        //2.刷新表格
        [self.tableView reloadData];
        
        //3.显示数据到底部
        [self scrollToBottom];
        
    }
}

#pragma mark - Action

- (IBAction)voiceAction:(UIButton *)sender {
    
    // 1.显示录音按钮
    self.recordBtn.hidden = !self.recordBtn.hidden;
    self.textView.hidden  = ! self.textView.hidden;
    
    if (self.recordBtn.hidden == NO) {//录音按钮要显示
        //InputToolBar 的高度要回来默认(46);
        self.inputToolBarHegihtConstraint.constant = 46;
        // 隐藏键盘
        [self.view endEditing:YES];
    }else{
        //当不录音的时候，键盘显示
        [self.textView becomeFirstResponder];
        
        // 恢复InputToolBar高度
        [self textViewDidChange:self.textView];
    }
    
}


#pragma mark 按钮点下去开始录音
- (IBAction)beginRecordAction:(id)sender {
    // 文件名以时间命名
    int x = arc4random() % 100000;
    NSTimeInterval time = [[NSDate date] timeIntervalSince1970];
    NSString *fileName = [NSString stringWithFormat:@"%d%d",(int)time,x];
    
    NSLog(@"按钮点下去开始录音");
    [[EMCDDeviceManager sharedInstance] asyncStartRecordingWithFileName:fileName completion:^(NSError *error) {
        if (!error) {
            NSLog(@"开始录音成功");
        }
    }];
}

#pragma mark 手指从按钮范围内松开结束录音
- (IBAction)endRecordAction:(id)sender {
    NSLog(@"手指从按钮松开结束录音");
    [[EMCDDeviceManager sharedInstance] asyncStopRecordingWithCompletion:^(NSString *recordPath, NSInteger aDuration, NSError *error) {
        if (!error) {
            NSLog(@"录音成功");
            NSLog(@"%@",recordPath);
            // 发送语音给服务器
            [self sendVoice:recordPath duration:aDuration];
            
        }else{
            NSLog(@"== %@",error);
            
        }
    }];
}


#pragma mark 发送语音消息
-(void)sendVoice:(NSString *)recordPath duration:(NSInteger)duration{
    // 1.构造一个 语音消息体
    EMChatVoice *chatVoice = [[EMChatVoice alloc] initWithFile:recordPath displayName:@"[语音]"];
    //    chatVoice.duration = duration;
    
    EMVoiceMessageBody *voiceBody = [[EMVoiceMessageBody alloc] initWithChatObject:chatVoice];
    voiceBody.duration = duration;
    
    [self sendMessage:voiceBody];
    
}


#pragma mark 发送图片
-(void)sendImg:(UIImage *)selectedImg{
    
    //1.构造图片消息体
    /*
     * 第一个参数：原始大小的图片对象 1000 * 1000
     * 第二个参数: 缩略图的图片对象  120 * 120
     */
    EMChatImage *orginalChatImg = [[EMChatImage alloc] initWithUIImage:selectedImg displayName:@"【图片】"];
    
    EMImageMessageBody *imgBody = [[EMImageMessageBody alloc] initWithImage:orginalChatImg thumbnailImage:nil];
    
    [self sendMessage:imgBody];
    
}

-(void)sendMessage:(id<IEMMessageBody>)body{
    //1.构造消息对象
    EMMessage *msgObj = [[EMMessage alloc] initWithReceiver:self.buddy.username bodies:@[body]];
    msgObj.messageType = eMessageTypeChat;
    
    //2.发送消息
    [[EaseMob sharedInstance].chatManager asyncSendMessage:msgObj progress:nil prepare:^(EMMessage *message, EMError *error) {
        NSLog(@"准备发送图片");
    } onQueue:nil completion:^(EMMessage *message, EMError *error) {
        NSLog(@"图片发送成功 %@",error);
    } onQueue:nil];
    
    // 3.把消息添加到数据源，然后再刷新表格
    [self addDataSourcesWithMessage:msgObj];
    [self.tableView reloadData];
    // 4.把消息显示在顶部
    [self scrollToBottom];
    
}


#pragma mark 手指从按钮外面松开取消录音
- (IBAction)cancelRecordAction:(id)sender {
    [[EMCDDeviceManager sharedInstance] cancelCurrentRecording];
    
}

- (IBAction)showImgPickerAction:(id)sender {
    //显示图片选择的控制器
    UIImagePickerController *imgPicker = [[UIImagePickerController alloc] init];
    
    // 设置源
    imgPicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imgPicker.delegate = self;
    
    [self presentViewController:imgPicker animated:YES completion:NULL];
}

/**用户选中图片的回调*/
-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info{
    
    //1.获取用户选中的图片
    UIImage *selectedImg =  info[UIImagePickerControllerOriginalImage];
    
    //2.发送图片
    [self sendImg:selectedImg];
    
    //3.隐藏当前图片选择控制器
    [self dismissViewControllerAnimated:YES completion:NULL];
    
}

-(void)scrollViewWillBeginDragging:(UIScrollView *)scrollView{
    //停止语音播放
    [SCUTAudioPlayTool stop];
}

-(void)addDataSourcesWithMessage:(EMMessage *)msg{

//        if (self.dataSources.count == 0) {  //模拟数据
//            long long timestamp = ([[NSDate date] timeIntervalSince1970] - 60 * 60 * 24 * 2) * 1000;
//             NSString *timeStr = [SCUTTimeTool timeStr:timestamp];
//            [self.dataSources addObject:timeStr];
//        }
    
//     1.判断EMMessage对象前面是否要加 "时间"
    NSString *timeStr = [SCUTTimeTool timeStr:msg.timestamp];
    if (![self.currentTimeStr isEqualToString:timeStr]) {
        [self.dataSources addObject:timeStr];
        self.currentTimeStr = timeStr;
    }
    
    // 2.再加EMMessage
    [self.dataSources addObject:msg];
    
    // 3.设置消息为已读取
    [self.conversation markMessageWithId:msg.messageId asRead:YES];

}


@end
