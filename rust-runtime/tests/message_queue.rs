//! Tests for MessageQueue core module

use patlang_runtime::message_queue::{Message, MessageQueue};
use tokio::sync::mpsc;
use tokio::time::{timeout, Duration};

#[tokio::test]
async fn test_message_queue_send_and_receive() {
    let (queue, mut rx) = MessageQueue::new(8);
    let msg = Message {
        sender: "A".to_string(),
        recipient: "B".to_string(),
        payload: vec![1, 2, 3],
    };
    queue.send(msg.clone()).await.unwrap();
    // Check async receive
    let received = timeout(Duration::from_millis(100), rx.recv()).await.unwrap().unwrap();
    assert_eq!(received.sender, "A");
    assert_eq!(received.recipient, "B");
    assert_eq!(received.payload, vec![1, 2, 3]);
    // Check sync receive
    let (queue2, _) = MessageQueue::new(4);
    assert!(queue2.try_receive().is_none());
}

#[tokio::test]
async fn test_message_queue_len_and_empty() {
    let (queue, _rx) = MessageQueue::new(4);
    assert_eq!(queue.len(), 0);
    assert!(queue.is_empty());
    let msg = Message {
        sender: "X".to_string(),
        recipient: "Y".to_string(),
        payload: vec![9, 8],
    };
    queue.send(msg).await.unwrap();
    assert_eq!(queue.len(), 1);
    assert!(!queue.is_empty());
}

#[tokio::test]
async fn test_message_queue_error_handling() {
    let (queue, mut rx) = MessageQueue::new(1);
    let msg1 = Message {
        sender: "S".to_string(),
        recipient: "R".to_string(),
        payload: vec![0],
    };
    let msg2 = msg1.clone();
    queue.send(msg1).await.unwrap();
    // Fill the channel, then drop receiver to cause send error
    drop(rx);
    let result = queue.send(msg2).await;
    assert!(result.is_err());
}